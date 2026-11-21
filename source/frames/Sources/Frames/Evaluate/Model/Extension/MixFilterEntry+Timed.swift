//
//  MixFilterEntry+Timed.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// An entry of a sound's resolved audio filter, `{ops, mix}`, as a segment carries it, each leaf written by `sampler`.
// Resolve writes every parameter, its default included, so an op or a band missing one is left out.
extension MixFilterEntry {
    // MARK: - Property
    // MARK: - Initializer
    init?(
        timed entry: TimedValue,
        sampler: MixValueSampler
    ) {
        guard
            case let .list(operations) = entry["ops"],
            let mix = sampler.value(entry["mix"], as: LeafKind.number(.range(0...1)))
        else {
            return nil
        }

        self.init(operations: operations.compactMap { Self.operation($0, sampler: sampler) }, mix: mix)
    }

    // MARK: - Public
    // MARK: - Private
    private static func operation(
        _ value: TimedValue,
        sampler: MixValueSampler
    ) -> MixFilterOperation? {
        guard case let .form(form, body) = value, case let .object(structure) = LookStructureTable.audioOperation(
            String(form.dropFirst("op:".count))
        ) else {
            return nil
        }

        let number = { (key: String) -> MixValue? in
            guard case let .leaf(kind) = structure.structure(of: key) else { return nil }

            return sampler.value(body[key], as: kind)
        }

        switch form {
        case "op:eq":
            guard case let .list(bands) = body["bands"], case let .list(band) = structure.structure(of: "bands") else {
                return nil
            }

            return .eq(bands: bands.compactMap { self.band($0, structure: band, sampler: sampler) })

        case "op:compressor":
            guard
                let threshold = number("threshold"),
                let ratio = number("ratio"),
                let knee = number("knee"),
                let attack = number("attack"),
                let release = number("release"),
                let makeup = number("makeup")
            else {
                return nil
            }

            return .compressor(MixCompressor(
                threshold: threshold,
                ratio: ratio,
                knee: knee,
                attack: attack,
                release: release,
                makeup: makeup
            ))

        case "op:limiter":
            guard
                let gain = number("gain"),
                let ceiling = number("ceiling"),
                let lookahead = staticNumber(body["lookahead"], sampler: sampler),
                let release = number("release")
            else {
                return nil
            }

            return .limiter(MixLimiter(gain: gain, ceiling: ceiling, lookahead: lookahead, release: release))

        default:
            guard
                let threshold = number("threshold"),
                let range = number("range"),
                let attack = number("attack"),
                let hold = number("hold"),
                let release = number("release")
            else {
                return nil
            }

            return .gate(MixGate(threshold: threshold, range: range, attack: attack, hold: hold, release: release))
        }
    }

    // A static number, such as a limiter's `lookahead`: written as it is, or one value over the whole sound.
    private static func staticNumber(
        _ value: TimedValue?,
        sampler: MixValueSampler
    ) -> Double? {
        if case let .fixed(written) = value {
            return written.numberValue
        }
        guard case let .constant(number) = sampler.value(value, as: .number()) else { return nil }

        return number
    }

    private static func band(
        _ value: TimedValue,
        structure: ValueStructure,
        sampler: MixValueSampler
    ) -> MixBand? {
        guard
            case let .form(form, body) = value,
            let type = MixBandType(rawValue: String(form.dropFirst("type:".count))),
            case let .object(band) = structure.structure(ofForm: form)
        else {
            return nil
        }

        let number = { (key: String) -> MixValue? in
            guard case let .leaf(kind) = band.structure(of: key) else { return nil }

            return sampler.value(body[key], as: kind)
        }

        guard let frequency = number("frequency"), let q = number("q") else { return nil }

        let gain = number("gain")
        guard !type.takesGain || gain != nil else { return nil }

        return MixBand(type: type, frequency: frequency, gain: gain, q: q)
    }
}

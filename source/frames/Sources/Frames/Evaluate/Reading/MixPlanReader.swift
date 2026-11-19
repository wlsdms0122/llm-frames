//
//  MixPlanReader.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Reads a mix plan as `MixPlanWriter` writes it. The version is checked before anything else, and a member that is
// missing or of another type, or a key the writer never writes there, stops naming its place.
package struct MixPlanReader: Sendable {
    // MARK: - Property
    private static let segmentKeys = ["media", "mediaStart", "speed", "start", "end", "filter", "envelope", "pan"]
    private static let compressorKeys = ["op", "threshold", "ratio", "knee", "attack", "release", "makeup"]
    private static let gateKeys = ["op", "threshold", "range", "attack", "hold", "release"]
    private static let operationKeys = ["op", "bands", "threshold", "ratio", "knee", "range", "attack", "hold", "release", "makeup"]

    private let checker: ResolvedDocumentChecker
    private let values = ResolvedValueReader()

    // MARK: - Initializer
    package init() {
        self.init(checker: ResolvedDocumentChecker())
    }

    init(checker: ResolvedDocumentChecker) {
        self.checker = checker
    }

    // MARK: - Public
    package func read(_ text: String) throws -> MixPlan {
        try read(JSONReader().read(text))
    }

    func read(_ value: JSONValue) throws -> MixPlan {
        let root = PlacedJSONValue(value, place: .root, kind: "mix plan")
        let version = try values.member("mixPlan", of: root, kind: root.kind)
        let written = version.value.stringValue ?? version.value.written
        guard checker.isReadable(written) else {
            throw EvaluateError.unreadableVersion(
                place: version.place,
                kind: root.kind,
                form: "mix plan",
                written: written,
                current: checker.current
            )
        }

        let plan = try root.object(keys: ["mixPlan", "segments"])

        return MixPlan(segments: try plan.member("segments").elements().map(segment))
    }

    // MARK: - Private
    private func segment(_ value: PlacedJSONValue) throws -> MixSegment {
        let segment = try value.object(kind: "segment", keys: Self.segmentKeys)

        return MixSegment(
            media: try values.media(segment.member("media")),
            mediaStart: try segment.member("mediaStart").number(),
            speed: try segment.member("speed").number(),
            start: try segment.member("start").number(),
            end: try segment.member("end").number(),
            filter: try segment.member("filter").elements().map(entry),
            envelope: try points(segment.member("envelope")),
            pan: try points(segment.member("pan"))
        )
    }

    private func entry(_ value: PlacedJSONValue) throws -> MixFilterEntry {
        let entry = try value.object(kind: "filter entry", keys: ["ops", "mix"])

        return MixFilterEntry(
            operations: try entry.member("ops").elements().map(operation),
            mix: try mixValue(entry.member("mix"))
        )
    }

    // The op's name is read first, so a key stops by the keys of the op it is written in.
    private func operation(_ value: PlacedJSONValue) throws -> MixFilterOperation {
        let name = try value.object(kind: "audio op", keys: Self.operationKeys).member("op")
            .name(among: MixFilterOperation.names) { MixFilterOperation.names.contains($0) ? $0 : nil }

        switch name {
        case "eq":
            let eq = try value.object(kind: "eq", keys: ["op", "bands"])
            return .eq(bands: try eq.member("bands").elements().map(band))

        case "compressor":
            let compressor = try value.object(kind: "compressor", keys: Self.compressorKeys)
            return .compressor(MixCompressor(
                threshold: try mixValue(compressor.member("threshold")),
                ratio: try mixValue(compressor.member("ratio")),
                knee: try mixValue(compressor.member("knee")),
                attack: try mixValue(compressor.member("attack")),
                release: try mixValue(compressor.member("release")),
                makeup: try mixValue(compressor.member("makeup"))
            ))

        default:
            let gate = try value.object(kind: "gate", keys: Self.gateKeys)
            return .gate(MixGate(
                threshold: try mixValue(gate.member("threshold")),
                range: try mixValue(gate.member("range")),
                attack: try mixValue(gate.member("attack")),
                hold: try mixValue(gate.member("hold")),
                release: try mixValue(gate.member("release"))
            ))
        }
    }

    private func band(_ value: PlacedJSONValue) throws -> MixBand {
        let type = try value.object(kind: "band", keys: ["type", "frequency", "gain", "q"]).member("type")
            .name(among: MixBandType.allCases.map(\.rawValue)) { MixBandType(rawValue: $0) }
        let keys = type.takesGain ? ["type", "frequency", "gain", "q"] : ["type", "frequency", "q"]
        let band = try value.object(kind: "\(type.rawValue) band", keys: keys)

        return MixBand(
            type: type,
            frequency: try mixValue(band.member("frequency")),
            gain: type.takesGain ? try mixValue(band.member("gain")) : nil,
            q: try mixValue(band.member("q"))
        )
    }

    private func mixValue(_ value: PlacedJSONValue) throws -> MixValue {
        if let number = value.value.numberValue {
            return .constant(number)
        }
        guard let elements = value.value.arrayValue, !elements.isEmpty else {
            throw value.wrongType("a number or a list of [time, value] points")
        }

        return .envelope(try points(value))
    }

    private func points(_ value: PlacedJSONValue) throws -> [EnvelopePoint] {
        try value.elements().map { element in
            let numbers = try element.numbers(count: 2)

            return EnvelopePoint(time: numbers[0], value: numbers[1])
        }
    }
}

//
//  MixPlanWriter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Writes a mix plan in the layout and number form of a resolved document, so the same plan gives the same bytes.
package struct MixPlanWriter: Sendable {
    // MARK: - Property
    private let values = ResolvedValueWriter()
    private let writer = JSONWriter()

    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    package func write(_ plan: MixPlan) -> String {
        writer.write(document(plan))
    }

    func document(_ plan: MixPlan) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "mixPlan", value: .string(FramesVersion.current)),
            JSONMember(key: "length", value: .number(Double(plan.length))),
            JSONMember(key: "segments", value: .array(plan.segments.map(segment))),
            JSONMember(key: "buses", value: .array(plan.buses.map(bus))),
            JSONMember(key: "filter", value: .array(plan.filter.map(entry)))
        ]))
    }

    // MARK: - Private
    private func bus(_ bus: MixBus) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "start", value: .number(bus.start)),
            JSONMember(key: "end", value: .number(bus.end)),
            JSONMember(key: "segments", value: .array(bus.segments.map(segment))),
            JSONMember(key: "buses", value: .array(bus.buses.map(self.bus))),
            JSONMember(key: "filter", value: .array(bus.filter.map(entry))),
            JSONMember(key: "envelope", value: points(bus.envelope))
        ]))
    }

    private func segment(_ segment: MixSegment) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "media", value: media(segment.media)),
            JSONMember(key: "mediaStart", value: .number(segment.mediaStart)),
            JSONMember(key: "speed", value: .number(segment.speed)),
            JSONMember(key: "start", value: .number(segment.start)),
            JSONMember(key: "end", value: .number(segment.end)),
            JSONMember(key: "filter", value: .array(segment.filter.map(entry))),
            JSONMember(key: "envelope", value: points(segment.envelope)),
            JSONMember(key: "pan", value: points(segment.pan))
        ]))
    }

    // Pinned media as a resolved document writes it, and a file nothing pins in the form of a pinned file, its hash and
    // frame times null.
    private func media(_ media: MixMedia) -> JSONValue {
        switch media {
        case let .pinned(media):
            values.media(media)

        case let .unpinned(path):
            .object(JSONObject(members: [
                JSONMember(key: "kind", value: .string("file")),
                JSONMember(key: "file", value: .string(path)),
                JSONMember(key: "sha256", value: .null),
                JSONMember(key: "frames", value: .null)
            ]))
        }
    }

    private func entry(_ entry: MixFilterEntry) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "ops", value: .array(entry.operations.map(operation))),
            JSONMember(key: "mix", value: value(entry.mix))
        ]))
    }

    private func operation(_ operation: MixFilterOperation) -> JSONValue {
        let name = JSONMember(key: "kind", value: .string(operation.name))
        let members: [JSONMember] = switch operation {
        case let .eq(bands):
            [JSONMember(key: "bands", value: .array(bands.map(band)))]

        case let .compressor(compressor):
            [
                JSONMember(key: "threshold", value: value(compressor.threshold)),
                JSONMember(key: "ratio", value: value(compressor.ratio)),
                JSONMember(key: "knee", value: value(compressor.knee)),
                JSONMember(key: "attack", value: value(compressor.attack)),
                JSONMember(key: "release", value: value(compressor.release)),
                JSONMember(key: "makeup", value: value(compressor.makeup))
            ]

        case let .gate(gate):
            [
                JSONMember(key: "threshold", value: value(gate.threshold)),
                JSONMember(key: "range", value: value(gate.range)),
                JSONMember(key: "attack", value: value(gate.attack)),
                JSONMember(key: "hold", value: value(gate.hold)),
                JSONMember(key: "release", value: value(gate.release))
            ]

        case let .limiter(limiter):
            [
                JSONMember(key: "gain", value: value(limiter.gain)),
                JSONMember(key: "ceiling", value: value(limiter.ceiling)),
                JSONMember(key: "lookahead", value: .number(limiter.lookahead)),
                JSONMember(key: "release", value: value(limiter.release))
            ]

        case let .convolve(convolution):
            values.pinned(convolution.file) + [JSONMember(key: "gain", value: value(convolution.gain))]
        }

        return .object(JSONObject(members: [name] + members))
    }

    private func band(_ band: MixBand) -> JSONValue {
        let gain = band.gain.map { [JSONMember(key: "gain", value: value($0))] } ?? []

        return .object(JSONObject(members: [
            JSONMember(key: "kind", value: .string(band.type.rawValue)),
            JSONMember(key: "frequency", value: value(band.frequency))
        ] + gain + [
            JSONMember(key: "q", value: value(band.q))
        ]))
    }

    private func value(_ value: MixValue) -> JSONValue {
        switch value {
        case let .constant(number):
            .number(number)

        case let .envelope(points):
            self.points(points)
        }
    }

    private func points(_ points: [EnvelopePoint]) -> JSONValue {
        .array(points.map { point in values.numbers([point.time, point.value]) })
    }
}

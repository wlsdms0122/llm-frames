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
            JSONMember(key: "segments", value: .array(plan.segments.map(segment)))
        ]))
    }

    // MARK: - Private
    private func segment(_ segment: MixSegment) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "media", value: .object(JSONObject(members: values.media(segment.media)))),
            JSONMember(key: "mediaStart", value: .number(segment.mediaStart)),
            JSONMember(key: "speed", value: .number(segment.speed)),
            JSONMember(key: "start", value: .number(segment.start)),
            JSONMember(key: "end", value: .number(segment.end)),
            JSONMember(key: "filter", value: .array(segment.filter.map(entry))),
            JSONMember(key: "envelope", value: points(segment.envelope)),
            JSONMember(key: "pan", value: points(segment.pan))
        ]))
    }

    private func entry(_ entry: MixFilterEntry) -> JSONValue {
        .object(JSONObject(members: [
            JSONMember(key: "ops", value: .array(entry.operations.map(operation))),
            JSONMember(key: "mix", value: value(entry.mix))
        ]))
    }

    private func operation(_ operation: MixFilterOperation) -> JSONValue {
        let name = JSONMember(key: "op", value: .string(operation.name))
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
        }

        return .object(JSONObject(members: [name] + members))
    }

    private func band(_ band: MixBand) -> JSONValue {
        let gain = band.gain.map { [JSONMember(key: "gain", value: value($0))] } ?? []

        return .object(JSONObject(members: [
            JSONMember(key: "type", value: .string(band.type.rawValue)),
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

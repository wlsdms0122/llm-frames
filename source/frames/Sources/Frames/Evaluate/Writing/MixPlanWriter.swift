//
//  MixPlanWriter.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Writes a mix plan as JSON, `"mixPlan"` first, set to the version of this frames, then its segments in plan order,
// each with its pinned media under `media`, its envelope as `[time, gain]` points and its pan envelope as `[time, pan]`
// points, in the layout and number form of a resolved document, so the same plan gives the same bytes.
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
            JSONMember(key: "envelope", value: points(segment.envelope)),
            JSONMember(key: "pan", value: points(segment.pan))
        ]))
    }

    private func points(_ points: [EnvelopePoint]) -> JSONValue {
        .array(points.map { point in values.numbers([point.time, point.value]) })
    }
}

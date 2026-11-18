//
//  MixPlanReader.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Reads a mix plan from its JSON text as `MixPlanWriter` writes it, by the rule a resolved document is read by: its
// version is checked before anything else, and a member that is missing or of another type, or a key the writer never
// writes there, stops naming its place.
package struct MixPlanReader: Sendable {
    // MARK: - Property
    private static let segmentKeys = ["media", "mediaStart", "speed", "start", "end", "envelope"]

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
            envelope: try segment.member("envelope").elements().map { element in
                let numbers = try element.numbers(count: 2)

                return EnvelopePoint(time: numbers[0], value: numbers[1])
            }
        )
    }
}

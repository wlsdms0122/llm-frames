//
//  ResolvedPictureReader.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Reads a resolved image or layout document as `ResolvedPictureWriter` writes it: its final size and its drawing
// steps, each with the `place`, `id` and `kind` of what drew it, what it draws under `draw` and the canvas it is
// clipped to under `clip`.
struct ResolvedPictureReader: Sendable {
    // MARK: - Property
    static let keys = ["kind", "size", "steps"]

    private static let drawingNames = ["picture", "fill", "box", "dim", "arrow", "adjust", "text", "border"]

    private let values = ResolvedValueReader()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `object` holds a picture of `kind`, its keys already checked. `sequences` reads a compound clip's sequence a
    // step draws, which the sequence reader owns.
    func picture(
        _ object: PlacedJSONObject,
        kind: String,
        sequences: (PlacedJSONObject) throws -> ResolvedSequence
    ) throws -> ResolvedPicture {
        ResolvedPicture(
            kind: kind,
            size: try values.size(object.member("size")),
            steps: try object.member("steps").elements().map { element in
                try step(element, sequences: sequences)
            }
        )
    }

    // MARK: - Private
    // `draw` names what a step draws, which decides the keys it holds besides what drew it and `clip`.
    private func step(
        _ value: PlacedJSONValue,
        sequences: (PlacedJSONObject) throws -> ResolvedSequence
    ) throws -> ResolvedDrawingStep {
        let name = try values.member("draw", of: value, kind: "drawing step")
            .name(among: Self.drawingNames) { Self.drawingNames.contains($0) ? $0 : nil }
        let step = try value.object(
            kind: "drawing step",
            keys: ["place", "id", "kind", "draw"] + keys(of: name) + ["clip"]
        )
        let rectangle = { (key: String) in try values.rectangle(step.member(key)) }
        let point = { (key: String) in try values.point(step.member(key)) }
        let number = { (key: String) in try step.member(key).number() }
        let color = { try values.color(step.member("color")) }

        let content: ResolvedDrawingContent = switch name {
        case "picture":
            .picture(
                try picture(step.member("picture"), sequences: sequences),
                crop: try rectangle("crop"),
                frame: try rectangle("frame")
            )

        case "fill":
            .fill(try rectangle("area"), color: try color())

        case "box":
            .box(try rectangle("area"), width: try number("width"), radius: try number("radius"), color: try color())

        case "dim":
            .dim(try rectangle("area"), color: try color())

        case "arrow":
            .arrow(
                tail: try point("tail"),
                tip: try point("tip"),
                width: try number("width"),
                head: try number("head"),
                color: try color()
            )

        case "adjust":
            .adjustment(try values.filter(step.member("filter")), area: try rectangle("area"))

        case "text":
            .text(try values.text(step.member("text")), frame: try rectangle("frame"))

        default:
            .border(try rectangle("area"), width: try number("width"), color: try color())
        }

        return ResolvedDrawingStep(
            place: try step.member("place").string(),
            id: try step.member("id").optional { try $0.string() },
            kind: try step.member("kind").string(),
            content: content,
            clip: try rectangle("clip")
        )
    }

    private func keys(of name: String) -> [String] {
        switch name {
        case "picture":
            ["picture", "crop", "frame"]

        case "fill", "dim":
            ["area", "color"]

        case "box":
            ["area", "width", "radius", "color"]

        case "arrow":
            ["tail", "tip", "width", "head", "color"]

        case "adjust":
            ["area", "filter"]

        case "text":
            ["text", "frame"]

        default:
            ["area", "width", "color"]
        }
    }

    // Pinned media at its media second, a nested image or layout document, or a compound clip's sequence with the
    // time of its own it is shown at.
    private func picture(
        _ value: PlacedJSONValue,
        sequences: (PlacedJSONObject) throws -> ResolvedSequence
    ) throws -> ResolvedDrawnPicture {
        guard value.value.objectValue?.contains("kind") == true else {
            let media = try value.object(kind: "media", keys: ResolvedValueReader.mediaKeys + ["time"])

            return .media(try values.media(media), time: try media.member("time").number())
        }

        let kind = try values.documentKind(value)
        guard kind == "sequence" else {
            return .picture(try picture(value.object(kind: kind, keys: Self.keys), kind: kind, sequences: sequences))
        }

        let sequence = try value.object(kind: kind, keys: ResolvedSequenceReader.keys + ["time"])

        return .sequence(try sequences(sequence), time: try sequence.member("time").number())
    }
}

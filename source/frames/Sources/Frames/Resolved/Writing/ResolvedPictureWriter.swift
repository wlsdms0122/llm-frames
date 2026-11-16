//
//  ResolvedPictureWriter.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Writes a resolved image or layout document as the members of its resolved document after `kind`: its final size and
// its drawing steps in operation order, in output pixels, each with what it draws under `draw` and the canvas it is
// clipped to under `clip`.
struct ResolvedPictureWriter: Sendable {
    // MARK: - Property
    private let values = ResolvedValueWriter()

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `sequences` writes a compound clip's sequence a step draws, which the sequence writer owns.
    func members(
        of picture: ResolvedPicture,
        sequences: (ResolvedSequence) -> [JSONMember]
    ) -> [JSONMember] {
        [
            JSONMember(key: "size", value: values.size(picture.size)),
            JSONMember(key: "steps", value: .array(picture.steps.map { step in
                .object(JSONObject(
                    members: members(of: step.content, sequences: sequences)
                        + [JSONMember(key: "clip", value: values.rectangle(step.clip))]
                ))
            }))
        ]
    }

    // MARK: - Private
    private func members(
        of content: ResolvedDrawingContent,
        sequences: (ResolvedSequence) -> [JSONMember]
    ) -> [JSONMember] {
        let draw = { (name: String) in JSONMember(key: "draw", value: .string(name)) }
        let area = { (rectangle: Rectangle) in JSONMember(key: "area", value: self.values.rectangle(rectangle)) }
        let color = { (color: Color) in JSONMember(key: "color", value: self.values.color(color)) }
        let number = { (key: String, number: Double) in JSONMember(key: key, value: .number(number)) }

        switch content {
        case let .picture(picture, crop, frame):
            return [
                draw("picture"),
                JSONMember(key: "picture", value: self.picture(picture, sequences: sequences)),
                JSONMember(key: "crop", value: values.rectangle(crop)),
                JSONMember(key: "frame", value: values.rectangle(frame))
            ]

        case let .fill(rectangle, fill):
            return [draw("fill"), area(rectangle), color(fill)]

        case let .box(rectangle, width, radius, stroke):
            return [draw("box"), area(rectangle), number("width", width), number("radius", radius), color(stroke)]

        case let .dim(rectangle, dim):
            return [draw("dim"), area(rectangle), color(dim)]

        case let .arrow(tail, tip, width, head, stroke):
            return [
                draw("arrow"),
                JSONMember(key: "tail", value: values.point(tail)),
                JSONMember(key: "tip", value: values.point(tip)),
                number("width", width),
                number("head", head),
                color(stroke)
            ]

        case let .adjustment(operations, rectangle):
            return [draw("adjust"), area(rectangle), JSONMember(key: "filter", value: values.filter(operations))]

        case let .text(text, frame):
            return [
                draw("text"),
                JSONMember(key: "text", value: values.text(text)),
                JSONMember(key: "frame", value: values.rectangle(frame))
            ]

        case let .border(rectangle, width, stroke):
            return [draw("border"), area(rectangle), number("width", width), color(stroke)]
        }
    }

    // Pinned media is shown at its media second. A nested document is written in place, a compound clip's sequence
    // with the time of its own it is shown at.
    private func picture(
        _ picture: ResolvedDrawnPicture,
        sequences: (ResolvedSequence) -> [JSONMember]
    ) -> JSONValue {
        switch picture {
        case let .media(media, time):
            return .object(JSONObject(members: values.media(media) + [JSONMember(key: "time", value: .number(time))]))

        case let .picture(picture):
            return .object(JSONObject(
                members: [JSONMember(key: "kind", value: .string(picture.kind))] + members(of: picture, sequences: sequences)
            ))

        case let .sequence(sequence, time):
            return .object(JSONObject(
                members: [JSONMember(key: "kind", value: .string("sequence"))] + sequences(sequence)
                    + [JSONMember(key: "time", value: .number(time))]
            ))
        }
    }
}

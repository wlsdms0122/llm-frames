//
//  AreaError.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

enum AreaError: Error, Equatable, CustomStringConvertible, Sendable {
    case ambiguousText(place: Place, kind: String, text: String, matches: [RecognisedLine])
    case noMatch(
        place: Place,
        kind: String,
        picture: String,
        mediaTime: Double,
        text: String,
        nth: Int?,
        matchCount: Int
    )
    case outsidePicture(place: Place, kind: String, rectangle: Rectangle, size: Size)
    case textInDocument(place: Place, kind: String, picture: String)
    case textInSolid(place: Place, kind: String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .ambiguousText(place, kind, text, matches):
            "\(place) (\(kind)): \(quoted(text)) matches \(matches.count) lines: "
                + matches.map { "\(written($0.rectangle)) \(quoted($0.text))" }.joined(separator: ", ")
                + ". Give nth to pick one"

        case let .noMatch(place, kind, picture, mediaTime, text, nil, _):
            "\(place) (\(kind)): no line of \(quoted(picture)) at media second \(number(mediaTime)) "
                + "contains \(quoted(text))"

        case let .noMatch(place, kind, picture, mediaTime, text, .some(nth), matchCount):
            "\(place) (\(kind)): \(matchCount) \(matchCount == 1 ? "line" : "lines") of \(quoted(picture)) at media "
                + "second \(number(mediaTime)) \(matchCount == 1 ? "contains" : "contain") \(quoted(text)), so there "
                + "is no line \(nth) (counted from 0)"

        case let .outsidePicture(place, kind, rectangle, size):
            "\(place) (\(kind)): the area \(written(rectangle)) lies wholly outside its picture of "
                + "\(number(size.width))x\(number(size.height))"

        case let .textInDocument(place, kind, picture):
            "\(place) (\(kind)): \(quoted(picture)) is drawn, not read, so it takes no text area. "
                + "Point at text inside it from the document that draws it"

        case let .textInSolid(place, kind):
            "\(place) (\(kind)): the clip's picture is a solid, not a media file, so it is drawn, not read, and "
                + "takes no text area"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    private func quoted(_ string: String) -> String {
        JSONValue.string(string).written
    }

    private func number(_ number: Double) -> String {
        JSONValue.number(number).written
    }

    private func written(_ rectangle: Rectangle) -> String {
        "[\([rectangle.x, rectangle.y, rectangle.width, rectangle.height].map(number).joined(separator: ", "))]"
    }
}

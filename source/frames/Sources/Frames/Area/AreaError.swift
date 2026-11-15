//
//  AreaError.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

enum AreaError: Error, Equatable, CustomStringConvertible, Sendable {
    case ambiguousText(place: Place, kind: String, text: String, matches: [RecognisedLine])
    case noMatch(place: Place, kind: String, picture: String, mediaTime: Double, text: String, nth: Int?)
    case outsidePicture(place: Place, kind: String, rectangle: Rectangle, size: Size)
    case textInDrawnPicture(place: Place, kind: String, picture: String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .ambiguousText(place, kind, text, matches):
            "\(place) (\(kind)): \(quoted(text)) matches \(matches.count) lines: "
                + matches.map { "\(written($0.rectangle)) \(quoted($0.text))" }.joined(separator: ", ")
                + ". Give nth to pick one"

        case let .noMatch(place, kind, picture, mediaTime, text, nth):
            "\(place) (\(kind)): "
                + (nth.map { "there is no line \($0) among the lines" } ?? "there is no line")
                + " of \(quoted(picture)) at \(number(mediaTime)) that contain \(quoted(text))"

        case let .outsidePicture(place, kind, rectangle, size):
            "\(place) (\(kind)): the area \(written(rectangle)) lies wholly outside its picture of "
                + "\(number(size.width))x\(number(size.height))"

        case let .textInDrawnPicture(place, kind, picture):
            "\(place) (\(kind)): \(quoted(picture)) is drawn, not read, so it takes no text area. "
                + "Point at text inside it from the document that draws it"
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

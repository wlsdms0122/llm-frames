//
//  TextError.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

enum TextError: Error, Equatable, CustomStringConvertible, Sendable {
    case noFontFamily(place: Place, kind: String, families: [String], weight: FontWeight)
    case tooWide(place: Place, kind: String, width: Double, room: Double)
    case lineBreakOnOneLine(place: Place, kind: String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .noFontFamily(place, kind, families, weight):
            "\(place) (\(kind)): no family of \(families.map(quoted).joined(separator: ", ")) "
                + "is in its pack or on the machine in \(weight.rawValue)"

        case let .tooWide(place, kind, width, room):
            "\(place) (\(kind)): the text is \(number(width)) wide on one line, wider than its room of \(number(room)), "
                + "and a cut line would say something else"

        case let .lineBreakOnOneLine(place, kind):
            "\(place) (\(kind)): the text has a line break, and its style keeps it on one line"
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
}

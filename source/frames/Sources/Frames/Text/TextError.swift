//
//  TextError.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

enum TextError: Error, Equatable, CustomStringConvertible, Sendable {
    case noFontFamily(place: Place, kind: String, families: [String], weight: FontWeight)
    case tooWide(place: Place, kind: String, width: Double, room: Double)
    case tooManyLines(place: Place, kind: String, count: Int, limit: Int)

    // MARK: - Property
    var description: String {
        switch self {
        case let .noFontFamily(place, kind, families, weight):
            "\(place) (\(kind)): no family of \(families.map(quoted).joined(separator: ", ")) "
                + "is in its pack or on the machine in \(weight.rawValue)"

        case let .tooWide(place, kind, width, room):
            "\(place) (\(kind)): the text is \(number(width)) wide on one line, wider than its room of "
                + "\(number(room)), and a cut line would say something else"

        case let .tooManyLines(place, kind, count, limit):
            "\(place) (\(kind)): the text takes \(count) lines, and its style allows at most \(limit)"
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

//
//  ThemeError.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ThemeError: Error, Equatable, CustomStringConvertible, Sendable {
    // `colors` are the names of the theme's colours, in name order.
    case unknownColor(place: Place, kind: String, name: String, colors: [String])
    case unknownStyle(place: Place, kind: String, name: String, styles: [String])
    case unknownShapeStyle(place: Place, kind: String, name: String, styles: [String])
    case unknownReference(place: Place, kind: String, reference: UnknownReference)
    case styleWithoutSize(place: Place, kind: String, name: String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .unknownColor(place, kind, name, colors):
            "\(place) (\(kind)): colour \"\(name)\" is not in colors, which hold \(Self.listed(colors))"
                + NameHint.suggestion(for: name, among: colors)

        case let .unknownStyle(place, kind, name, styles):
            "\(place) (\(kind)): style \"\(name)\" is not in styles, which hold \(Self.listed(styles))"
                + NameHint.suggestion(for: name, among: styles)

        case let .unknownShapeStyle(place, kind, name, styles):
            "\(place) (\(kind)): shape style \"\(name)\" is not in shapes, which hold \(Self.listed(styles))"
                + NameHint.suggestion(for: name, among: styles)

        case let .unknownReference(place, kind, reference):
            "\(place) (\(kind)): \(reference)"

        case let .styleWithoutSize(place, kind, name):
            "\(place) (\(kind)): style \"\(name)\" has no size, and text is set only in a style with one"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    // Names as a stop lists them, each in quotes, or `none`.
    private static func listed(_ names: [String]) -> String {
        names.isEmpty ? "none" : names.map { JSONValue.string($0).written }.joined(separator: ", ")
    }
}

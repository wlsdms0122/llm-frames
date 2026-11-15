//
//  ThemeError.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ThemeError: Error, Equatable, CustomStringConvertible, Sendable {
    case unknownColor(place: Place, kind: String, name: String)
    case unknownStyle(place: Place, kind: String, name: String)
    case unknownPreset(place: Place, kind: String, presetKind: String, name: String)
    case styleWithoutSize(place: Place, kind: String, name: String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .unknownColor(place, kind, name):
            "\(place) (\(kind)): colour \"\(name)\" is not in colors"

        case let .unknownStyle(place, kind, name):
            "\(place) (\(kind)): style \"\(name)\" is not in styles"

        case let .unknownPreset(place, kind, presetKind, name):
            "\(place) (\(kind)): unknown \(presetKind) preset \"\(name)\""

        case let .styleWithoutSize(place, kind, name):
            "\(place) (\(kind)): style \"\(name)\" has no size, and text is set only in a style with one"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

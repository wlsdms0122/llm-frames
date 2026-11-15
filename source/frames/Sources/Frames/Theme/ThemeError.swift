//
//  ThemeError.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ThemeError: Error, Equatable, CustomStringConvertible, Sendable {
    case unknownColor(place: Place, kind: String, name: String)
    case unknownStyle(place: Place, name: String)

    // MARK: - Property
    var description: String {
        switch self {
        case let .unknownColor(place, kind, name):
            "\(place) (\(kind)): colour \"\(name)\" is not in colors"

        case let .unknownStyle(place, name):
            "\(place) (title animations): style \"\(name)\" is not in styles"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

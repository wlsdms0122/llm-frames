//
//  ClipKind.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ClipKind: Equatable, Sendable {
    case media(MediaKind)
    case title
    case shape(String)
    case adjust
    case solid
    case null

    // MARK: - Property
    var label: String {
        switch self {
        case let .media(kind):
            kind == .sequence ? "compound" : kind.rawValue

        case .title:
            "title"

        case let .shape(shape):
            shape

        case .adjust:
            "adjustment"

        case .solid:
            "solid"

        case .null:
            "null"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

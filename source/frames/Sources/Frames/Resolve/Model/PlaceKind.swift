//
//  PlaceKind.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What a message names in parentheses after its place, in the words of the key tables: a clip's kind once its media
// is known, the clip of its place before that, or the sequence.
enum PlaceKind: Equatable, Sendable {
    case clip(ClipKind)
    case genericClip(ClipPlace)
    case sequence

    // MARK: - Property
    var label: String {
        switch self {
        case let .clip(kind):
            kind.label

        case let .genericClip(clipPlace):
            clipPlace.label

        case .sequence:
            DocumentKeyTable.sequence.kind
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

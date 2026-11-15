//
//  ClipPlace.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ClipPlace: Sendable {
    case storyline
    case connected
    case sequence

    // MARK: - Property
    // What a message calls a clip of this place before its kind is known.
    var label: String {
        switch self {
        case .storyline:
            "storyline clip"

        case .connected, .sequence:
            "clip"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

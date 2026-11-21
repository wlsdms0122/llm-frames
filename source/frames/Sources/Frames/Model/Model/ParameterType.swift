//
//  ParameterType.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

package enum ParameterType: String, Sendable {
    case video
    case sequence
    case image
    case audio
    case text
    case color
    case number
    case choice

    // MARK: - Property
    // The media kind a media parameter takes, nil for a value.
    var mediaKind: MediaKind? {
        MediaKind(rawValue: rawValue)
    }

    // MARK: - Initializer
    // MARK: - Public
    // Whether a media parameter of this type takes media of `kind`: `image` takes every still.
    func takes(_ kind: MediaKind) -> Bool {
        self == .image ? kind.isStill : mediaKind == kind
    }

    // MARK: - Private
}

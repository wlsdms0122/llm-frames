//
//  ClipContent.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

enum ClipContent: Equatable, Sendable {
    case media(ClipMedia)
    // A clip of its media's sound alone, which draws nothing.
    case audio(ClipMedia)
    case title(ClipTitle)
    case shape(ClipShape)
    case adjust
    case null(ClipNull)

    // MARK: - Property
    // The media a media clip or an audio clip plays, nil for a clip of another kind.
    var playedMedia: ClipMedia? {
        switch self {
        case let .media(media), let .audio(media):
            media

        case .title, .shape, .adjust, .null:
            nil
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

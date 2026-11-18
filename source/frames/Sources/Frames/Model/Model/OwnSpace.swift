//
//  OwnSpace.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A connected or sequence clip's own coordinate space (FRAMES-11), which its mask is written in and which it gives its
// children (FRAMES-10): a media clip's media pixels, the box of a title or of a rect or ellipse given by `width` and
// `height`, and for a shape placed by its geometry or an adjustment the space its parent gives, output pixels without
// one. A storyline clip's is always its media.
enum OwnSpace: Equatable, Sendable {
    case media
    case box
    case parent

    // MARK: - Property
    // MARK: - Initializer
    init(content: ClipContent) {
        switch content {
        case .media:
            self = .media

        case .title:
            self = .box

        case let .shape(shape):
            self = shape.width == nil ? .parent : .box

        case .adjust:
            self = .parent
        }
    }

    // The same space read back from a resolved entry, which writes a box shape's geometry as `box`.
    init(content: ResolvedClipContent) {
        switch content {
        case .media:
            self = .media

        case .title:
            self = .box

        case let .shape(shape):
            if case .box = shape.geometry { self = .box } else { self = .parent }

        case .adjustment:
            self = .parent
        }
    }

    // MARK: - Public
    // MARK: - Private
}

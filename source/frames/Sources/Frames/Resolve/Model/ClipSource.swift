//
//  ClipSource.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What a connected or sequence clip shows or plays: its kind, its media (nil for a title, shape or adjustment), and
// for timed media how it plays, with the start of its window left at 0 until the window is known.
struct ClipSource: Equatable, Sendable {
    // MARK: - Property
    let kind: ClipKind
    let media: ResolvedMedia?
    let timing: MediaTiming?

    // MARK: - Initializer
    init(
        kind: ClipKind,
        media: ResolvedMedia? = nil,
        timing: MediaTiming? = nil
    ) {
        self.kind = kind
        self.media = media
        self.timing = timing
    }

    // MARK: - Public
    // MARK: - Private
}

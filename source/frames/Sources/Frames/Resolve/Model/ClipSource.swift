//
//  ClipSource.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What a connected or sequence clip shows or plays: its kind, its media (nil for a title, shape or adjustment), and
// for timed media how it plays, nil for a still and for a clip without media.
struct ClipSource: Equatable, Sendable {
    // MARK: - Property
    let kind: ClipKind
    let media: MediaPlan?
    let timing: ClipTiming?

    // MARK: - Initializer
    init(
        kind: ClipKind,
        media: MediaPlan? = nil,
        timing: ClipTiming? = nil
    ) {
        self.kind = kind
        self.media = media
        self.timing = timing
    }

    // MARK: - Public
    // MARK: - Private
}

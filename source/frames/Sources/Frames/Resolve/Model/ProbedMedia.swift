//
//  ProbedMedia.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The probed facts of one media file that resolve reads. `frames` holds a video's frame timestamps in media time, and
// `size` is the picture's, nil for sound.
struct ProbedMedia: Equatable, Sendable {
    // MARK: - Property
    let kind: MediaKind
    let duration: Double
    let fps: Double?
    let frames: [Double]
    let size: Size?

    // MARK: - Initializer
    init(
        kind: MediaKind,
        duration: Double = 0,
        fps: Double? = nil,
        frames: [Double] = [],
        size: Size? = nil
    ) {
        self.kind = kind
        self.duration = duration
        self.fps = fps
        self.frames = frames
        self.size = size
    }

    // MARK: - Public
    // MARK: - Private
}

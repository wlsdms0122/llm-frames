//
//  ProbedMedia.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The probed facts of one media file that time reads. `frames` holds a video's frame timestamps in media time.
struct ProbedMedia: Equatable, Sendable {
    // MARK: - Property
    let kind: MediaKind
    let duration: Double
    let fps: Double?
    let frames: [Double]

    // MARK: - Initializer
    init(
        kind: MediaKind,
        duration: Double = 0,
        fps: Double? = nil,
        frames: [Double] = []
    ) {
        self.kind = kind
        self.duration = duration
        self.fps = fps
        self.frames = frames
    }

    // MARK: - Public
    // MARK: - Private
}

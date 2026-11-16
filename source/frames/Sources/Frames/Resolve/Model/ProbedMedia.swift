//
//  ProbedMedia.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The probed facts of one media file that resolve reads. `frames` holds a video's frame timestamps and `duration` its
// length, both in media time, whose 0 is a video's first presented frame. `size` is the picture's, nil for sound, and
// `hasSound` says whether the file holds a sound track.
package struct ProbedMedia: Equatable, Sendable {
    // MARK: - Property
    package let kind: MediaKind
    package let duration: Double
    package let fps: Double?
    package let frames: [Double]
    package let size: Size?
    package let hasSound: Bool

    // MARK: - Initializer
    package init(
        kind: MediaKind,
        duration: Double = 0,
        fps: Double? = nil,
        frames: [Double] = [],
        size: Size? = nil,
        hasSound: Bool = false
    ) {
        self.kind = kind
        self.duration = duration
        self.fps = fps
        self.frames = frames
        self.size = size
        self.hasSound = hasSound
    }

    // MARK: - Public
    // MARK: - Private
}

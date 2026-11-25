//
//  ResolvedTrack+Following.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

@testable import Frames

// A track of `/abs/screen.mp4` whose target is the rectangle at media time `mediaTime`, with the motion fitted to each
// frame given, as resolve writes it.
extension ResolvedTrack {
    // MARK: - Property
    // MARK: - Initializer
    init(
        target: Rectangle,
        mediaTime: Double,
        frames: [TrackedFrame]
    ) {
        self.init(
            media: PinnedMedia(
                source: .file(PinnedFile(path: "/abs/screen.mp4", sha256: String(repeating: "0", count: 64)), frameTimes: frames.map(\.time))
            ),
            track: Track(target: Quad(target), mediaTime: mediaTime, frames: frames)
        )
    }

    // MARK: - Public
    // MARK: - Private
}

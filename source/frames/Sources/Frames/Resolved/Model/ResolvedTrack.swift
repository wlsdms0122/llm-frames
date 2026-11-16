//
//  ResolvedTrack.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What the tracker followed: `target` is the area before padding on the frame at media time `mediaTime`, and `frames`
// its rectangle on every frame followed, in media time. `isBand` says the tracked area is a band, which keeps the full
// width of its picture and takes only the vertical part of the motion.
struct ResolvedTrack: Equatable, Sendable {
    // MARK: - Property
    let target: Rectangle
    let mediaTime: Double
    let isBand: Bool
    let frames: [TrackedFrame]

    var track: Track {
        Track(target: target, mediaTime: mediaTime, frames: frames)
    }

    // MARK: - Initializer
    init(
        target: Rectangle,
        mediaTime: Double,
        isBand: Bool,
        frames: [TrackedFrame]
    ) {
        self.target = target
        self.mediaTime = mediaTime
        self.isBand = isBand
        self.frames = frames
    }

    // MARK: - Public
    // MARK: - Private
}

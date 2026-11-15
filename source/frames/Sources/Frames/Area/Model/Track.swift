//
//  Track.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What the tracker followed: `target` is the area before padding on the frame at `mediaTime`, the clip's instant, and
// `frames` its rectangle on every frame followed, in time order. A time before the first frame or after the last holds
// the nearest one, as a handle past the end of the media holds its edge frame.
struct Track: Equatable, Sendable {
    // MARK: - Property
    let target: Rectangle
    let mediaTime: Double
    let frames: [TrackedFrame]

    // MARK: - Initializer
    init(
        target: Rectangle,
        mediaTime: Double,
        frames: [TrackedFrame]
    ) {
        self.target = target
        self.mediaTime = mediaTime
        self.frames = frames
    }

    // MARK: - Public
    // The motion on the frame shown at the media time: the last frame followed at or before it.
    func motion(atMediaTime time: Double) -> TrackMotion {
        guard let first = frames.first else { return .identity }

        let frame = frames.last { $0.time <= time } ?? first
        return TrackMotion(from: target, to: frame.rectangle)
    }

    // MARK: - Private
}

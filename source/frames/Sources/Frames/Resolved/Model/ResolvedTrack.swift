//
//  ResolvedTrack.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What the tracker followed: `target` is the area before padding on the frame at media time `mediaTime`, and `frames`
// its rectangle on every frame followed, in media time.
struct ResolvedTrack: Equatable, Sendable {
    // MARK: - Property
    let target: Rectangle
    let mediaTime: Double
    let frames: [TrackedFrame]

    var track: Track {
        Track(target: target, mediaTime: mediaTime, frames: frames)
    }

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
    // A rectangle where it is on the frame at a media time, brought back through the motion there to where it is at the
    // instant.
    func bringBack(
        _ rectangle: Rectangle,
        fromMediaTime time: Double
    ) -> Rectangle {
        track.motion(atMediaTime: time).bringBack(rectangle)
    }

    func bringBack(
        point: Point,
        fromMediaTime time: Double
    ) -> Point {
        track.motion(atMediaTime: time).bringBack(point)
    }

    func carry(
        _ rectangle: Rectangle,
        toMediaTime time: Double
    ) -> Rectangle {
        track.motion(atMediaTime: time).carry(rectangle)
    }

    // MARK: - Private
}

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
    // A rectangle where it is on the frame at a media time, brought back through the motion there to where it is at the
    // instant. A band keeps the full width of its picture.
    func bringBack(
        _ rectangle: Rectangle,
        fromMediaTime time: Double
    ) -> Rectangle {
        let motion = track.motion(atMediaTime: time)

        return isBand ? motion.bringBackBand(rectangle) : motion.bringBack(rectangle)
    }

    // A rectangle where it is at the instant, carried by the motion to the frame at a media time.
    func carry(
        _ rectangle: Rectangle,
        toMediaTime time: Double
    ) -> Rectangle {
        let motion = track.motion(atMediaTime: time)

        return isBand ? motion.carryBand(rectangle) : motion.carry(rectangle)
    }

    // A storyline crop brought back as `bringBack` does, except that a band crop takes only the vertical move of the
    // motion, so it keeps its ratio.
    func bringBack(
        crop: Rectangle,
        fromMediaTime time: Double
    ) -> Rectangle {
        let motion = track.motion(atMediaTime: time)

        return isBand ? motion.bringBackBandCrop(crop) : motion.bringBack(crop)
    }

    // A storyline crop carried as `carry` does, except that a band crop takes only the vertical move of the motion, so
    // it keeps its ratio.
    func carry(
        crop: Rectangle,
        toMediaTime time: Double
    ) -> Rectangle {
        let motion = track.motion(atMediaTime: time)

        return isBand ? motion.carryBandCrop(crop) : motion.carry(crop)
    }

    // MARK: - Private
}

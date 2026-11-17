//
//  ResolvedStorylineClip+Filling.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

@testable import Frames

// A storyline entry that writes none of its transform, so its picture fills a frame of `size` exactly.
extension ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    init(
        place: String,
        id: String?,
        media: ResolvedMediaContent?,
        solid: Color?,
        in: Double,
        out: Double,
        speed: Double,
        start: Double,
        end: Double,
        crop: [Keyframe<Crop>],
        track: ResolvedTrack?,
        filter: [ResolvedFilterOperation],
        transition: ResolvedTransition?,
        filling size: Size
    ) {
        self.init(
            place: place,
            id: id,
            media: media,
            solid: solid,
            in: `in`,
            out: out,
            speed: speed,
            start: start,
            end: end,
            crop: crop,
            track: track,
            filter: filter,
            box: ResolvedBox(
                size: size,
                position: [Keyframe(at: start, value: Point(x: 0, y: 0))],
                anchor: Point(x: size.width / 2, y: size.height / 2)
            ),
            opacity: [Keyframe(at: start, value: 1)],
            scale: [Keyframe(at: start, value: 1)],
            rotation: [Keyframe(at: start, value: 0)],
            blend: "normal",
            radius: 0,
            border: nil,
            shadow: nil,
            transition: transition
        )
    }

    // MARK: - Public
    // MARK: - Private
}

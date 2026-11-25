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
        content: ResolvedStorylineContent,
        in: Double,
        out: Double,
        speed: Double,
        start: Double,
        end: Double,
        crop: FollowedValue<Crop>,
        track: ResolvedTrack?,
        filter: TimedValue,
        isMotionBlurred: Bool = false,
        transition: ResolvedTransition?,
        filling size: Size
    ) {
        self.init(
            place: place,
            id: id,
            content: content,
            in: `in`,
            out: out,
            speed: speed,
            start: start,
            end: end,
            crop: crop,
            mask: nil,
            trackMatte: nil,
            track: track,
            filter: filter,
            placement: .transform(
                box: ResolvedBox(
                    size: size,
                    position: [Keyframe(at: start, value: Point(x: size.width / 2, y: size.height / 2))],
                    anchor: Point(x: size.width / 2, y: size.height / 2)
                ),
                scale: [Keyframe(at: start, value: .identity)],
                rotation: [Keyframe(at: start, value: 0)]
            ),
            opacity: [Keyframe(at: start, value: 1)],
            blend: "normal",
            isMotionBlurred: isMotionBlurred,
            radius: .off,
            border: .off,
            shadow: .off,
            transition: transition
        )
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  ResolvedStorylinePicture+Filling.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

@testable import Frames

// The picture of a storyline entry that writes none of its transform, so it fills a frame of `size` exactly, with
// every static value a keyframe at `start`.
extension ResolvedStorylinePicture {
    // MARK: - Property
    // MARK: - Initializer
    init(
        crop: FollowedValue<Crop>,
        track: ResolvedTrack? = nil,
        filter: TimedValue = .off,
        filling size: Size,
        from start: Double
    ) {
        self.init(
            placement: .transform(
                box: ResolvedBox(
                    size: size,
                    position: [Keyframe(at: start, value: Point(x: size.width / 2, y: size.height / 2))],
                    anchor: Point(x: size.width / 2, y: size.height / 2)
                ),
                scale: [Keyframe(at: start, value: .identity)],
                rotation: [Keyframe(at: start, value: 0)]
            ),
            crop: crop,
            mask: nil,
            trackMatte: nil,
            track: track,
            filter: filter,
            opacity: [Keyframe(at: start, value: 1)],
            blend: "normal",
            radius: .off,
            border: .off,
            shadow: .off
        )
    }

    // MARK: - Public
    // MARK: - Private
}

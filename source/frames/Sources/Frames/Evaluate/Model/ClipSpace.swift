//
//  ClipSpace.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// The coordinate space a clip's positions and areas are written in, at one instant. `transform` is P(t), the map from
// that space to output pixels of the list the clip is drawn in: its parent's chain composed down to the output, or the
// identity for an unparented clip. It is a similarity, so `scale` and `rotation` are its one scale and its turn in
// degrees. `frame` is the list's frame: what an adjustment without a mask covers. `clock` is the parent's media clock,
// which gives the media time a tracked clip follows. A tracked clip's values are where they are at the instant, and
// its track's motion is a moving parent between them and this space: `area` and `anchor` answer in the clip's values'
// coordinates, and `tracked(by:at:)` is the space that maps those coordinates to output pixels.
struct ClipSpace: Sendable {
    // MARK: - Property
    let frame: Rectangle
    let transform: AffineTransform
    let clock: MediaClock?

    var scale: Double {
        (transform.a * transform.a + transform.b * transform.b).squareRoot()
    }

    var rotation: Double {
        atan2(transform.b, transform.a) * 180 / .pi
    }

    // MARK: - Initializer
    init(
        frame: Rectangle,
        transform: AffineTransform = .identity,
        clock: MediaClock? = nil
    ) {
        self.frame = frame
        self.transform = transform
        self.clock = clock
    }

    // MARK: - Public
    // A clip's area at the time, each keyframe brought back to the instant when it is tracked.
    func area(
        of keyframes: [Keyframe<Rectangle>],
        track: ResolvedTrack?,
        at time: Double
    ) -> Rectangle {
        guard let track, let clock else { return keyframes.value(at: time) }

        return track.area(of: keyframes, on: clock, at: time)
    }

    // A point a clip writes, such as a shape's position, at the time, and a path's points, each keyframe brought back
    // to the instant when it is tracked.
    func point(
        of keyframes: [Keyframe<Point>],
        track: ResolvedTrack?,
        at time: Double
    ) -> Point {
        guard let track, let clock else { return keyframes.value(at: time) }

        return track.point(of: keyframes, on: clock, at: time)
    }

    func points(
        of keyframes: [Keyframe<[Point]>],
        track: ResolvedTrack?,
        at time: Double
    ) -> [Point] {
        guard let track, let clock else { return keyframes.value(at: time) }

        return track.points(of: keyframes, on: clock, at: time)
    }

    // A clip's masks at the time, each keyframe brought back to the instant when it is tracked.
    func masks(
        of keyframes: [Keyframe<[ResolvedMask]>],
        track: ResolvedTrack?,
        at time: Double
    ) -> [ResolvedMask] {
        guard let track, let clock else { return keyframes.value(at: time) }

        return track.masks(of: keyframes, on: clock, at: time)
    }

    // A box clip's anchor point at the time, `position + anchor`, each keyframe brought back to the instant when it is
    // tracked.
    func anchor(
        of box: ResolvedBox,
        track: ResolvedTrack?,
        at time: Double
    ) -> Point {
        let anchors = box.position.map { keyframe in
            Keyframe(
                at: keyframe.at,
                value: Point(x: keyframe.value.x + box.anchor.x, y: keyframe.value.y + box.anchor.y),
                ease: keyframe.ease
            )
        }
        guard let track, let clock else { return anchors.value(at: time) }

        return track.point(of: anchors, on: clock, at: time)
    }

    // The space a clip's values are carried in at the time: its track's motion there, then P(t).
    func tracked(
        by track: ResolvedTrack?,
        at time: Double
    ) -> ClipSpace {
        guard let track, let clock else { return self }

        return ClipSpace(
            frame: frame,
            transform: track.transform(on: clock, at: time).concatenating(transform),
            clock: clock
        )
    }

    // MARK: - Private
}

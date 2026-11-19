//
//  ClipSpace.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The coordinate space a clip's positions and areas are written in, at one instant. `transform` maps that space to
// output pixels of the list the clip is drawn in, the identity for an unparented clip; it is any affine map, as a
// parent may scale its axes apart and mirror. `frame` is the list's frame, what an adjustment without a mask covers,
// and `clock` the parent's media clock, which a tracked clip follows. A tracked clip's keyframes are each brought back
// to the instant through its track, so `area`, `point`, `points`, `masks` and `anchor` answer in the clip's values'
// coordinates, and `tracked(by:at:)` is the space that maps those to output pixels: the track's motion, then this
// space's map.
struct ClipSpace: Sendable {
    // MARK: - Property
    let frame: Rectangle
    let transform: AffineTransform
    let clock: MediaClock?

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
    func area(
        of keyframes: [Keyframe<Rectangle>],
        track: ResolvedTrack?,
        at time: Double
    ) -> Rectangle {
        guard let track, let clock else { return keyframes.value(at: time) }

        return track.area(of: keyframes, on: clock, at: time)
    }

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

    func masks(
        of masks: [ResolvedMask],
        track: ResolvedTrack?,
        at time: Double
    ) -> [MaskSample] {
        guard let track, let clock else { return masks.map { $0.sampled(at: time) } }

        return track.masks(of: masks, on: clock, at: time)
    }

    // A box clip's anchor point, `position + anchor`.
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

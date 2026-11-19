//
//  ResolvedTrack+TrackedValue.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Each keyframe of a tracked clip's geometry is brought back through the motion at its own `at` into the instant's
// coordinates, in the media pixels the clip follows, and interpolated there. `transform` carries the instant to the
// frame shown at a time.
extension ResolvedTrack {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func area(
        of keyframes: [Keyframe<Rectangle>],
        on clock: MediaClock,
        at time: Double
    ) -> Rectangle {
        let brought = keyframes.map { keyframe in
            Keyframe(
                at: keyframe.at,
                value: motion(atMediaTime: clock.mediaTime(atSequenceTime: keyframe.at)).bringBack(keyframe.value),
                ease: keyframe.ease
            )
        }

        return brought.value(at: time)
    }

    func point(
        of keyframes: [Keyframe<Point>],
        on clock: MediaClock,
        at time: Double
    ) -> Point {
        let brought = keyframes.map { keyframe in
            Keyframe(
                at: keyframe.at,
                value: motion(atMediaTime: clock.mediaTime(atSequenceTime: keyframe.at)).bringBack(keyframe.value),
                ease: keyframe.ease
            )
        }

        return brought.value(at: time)
    }

    func points(
        of keyframes: [Keyframe<[Point]>],
        on clock: MediaClock,
        at time: Double
    ) -> [Point] {
        let brought = keyframes.map { keyframe in
            let motion = self.motion(atMediaTime: clock.mediaTime(atSequenceTime: keyframe.at))
            return Keyframe(
                at: keyframe.at,
                value: keyframe.value.map { motion.bringBack($0) },
                ease: keyframe.ease
            )
        }

        return brought.value(at: time)
    }

    // A mask's box size and radius are divided by the motion's scale, and its feather is in output pixels and is not
    // brought back.
    func masks(
        of masks: [ResolvedMask],
        on clock: MediaClock,
        at time: Double
    ) -> [MaskSample] {
        let motion = { (time: Double) in self.motion(atMediaTime: clock.mediaTime(atSequenceTime: time)) }

        return masks.map { mask in
            mask.carried(
                area: { area, time, _ in motion(time).bringBack(area) },
                point: { point, time, _ in motion(time).bringBack(point) },
                scale: { time in 1 / motion(time).scale }
            ).sampled(at: time)
        }
    }

    // A crop is an upright region of its media, so it takes the motion's move and scale and not its rotation, and the
    // interpolated crop is carried by the motion at the time.
    func crop(
        of keyframes: [Keyframe<Crop>],
        on clock: MediaClock,
        at time: Double
    ) -> Rectangle {
        let brought = keyframes.map { keyframe in
            Keyframe(
                at: keyframe.at,
                value: Crop(uprightMotion(on: clock, at: keyframe.at).bringBack(keyframe.value.rectangle)),
                ease: keyframe.ease
            )
        }

        return uprightMotion(on: clock, at: time).carry(brought.value(at: time).rectangle)
    }

    func transform(
        on clock: MediaClock,
        at time: Double
    ) -> AffineTransform {
        motion(atMediaTime: clock.mediaTime(atSequenceTime: time)).transform
    }

    // MARK: - Private
    private func uprightMotion(
        on clock: MediaClock,
        at time: Double
    ) -> TrackMotion {
        motion(atMediaTime: clock.mediaTime(atSequenceTime: time)).upright
    }
}

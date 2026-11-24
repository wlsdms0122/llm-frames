//
//  ResolvedTrack+TrackedValue.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Each keyframe of a tracked clip's geometry is brought back through the motion at its own `at` to the track's frame,
// in the media pixels the clip follows, and interpolated there. A value true on the track's frame is not brought back,
// since the motion is the identity there. `transform` carries the track's frame to the frame shown at a time. The
// motion that carries a value is the motion of the media frame shown at T, the time's `frameTime`, so it adds no blur
// inside a frame (FRAMES-29).
extension ResolvedTrack {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func area(
        of keyframes: FollowedValue<Rectangle>,
        on clock: MediaClock,
        at time: SampleTime
    ) -> Rectangle {
        broughtBack(keyframes, on: clock) { $0.bringBack($1) }.value(at: time)
    }

    func point(
        of keyframes: FollowedValue<Point>,
        on clock: MediaClock,
        at time: SampleTime
    ) -> Point {
        broughtBack(keyframes, on: clock) { $0.bringBack($1) }.value(at: time)
    }

    // A path's tangent is an offset, brought back by the motion's linear part alone (FRAMES-12 The track).
    func offset(
        of keyframes: FollowedValue<Point>,
        on clock: MediaClock,
        at time: SampleTime
    ) -> Point {
        broughtBack(keyframes, on: clock) { $0.bringBack(offset: $1) }.value(at: time)
    }

    // A mask's box size and corner radii are divided by the motion's scale, and its feather is in output pixels and is not
    // brought back.
    func masks(
        of masks: [ResolvedMask],
        on clock: MediaClock,
        at time: SampleTime
    ) -> [MaskSample] {
        let motion = { (time: Double) in self.motion(atMediaTime: clock.mediaTime(atSequenceTime: time)) }

        return masks.map { mask in
            mask.carried(
                area: { area, time, _ in time.map { motion($0).bringBack(area) } ?? area },
                point: { point, time, _ in time.map { motion($0).bringBack(point) } ?? point },
                tangent: { tangent, time in time.map { motion($0).bringBack(offset: tangent) } ?? tangent },
                scale: { time in time.map { 1 / motion($0).scale } ?? 1 }
            ).sampled(at: time)
        }
    }

    // A crop is an upright region of its media, so it takes the motion's move and scale and not its rotation, and the
    // interpolated crop is carried by the motion at the time.
    func crop(
        of keyframes: FollowedValue<Crop>,
        on clock: MediaClock,
        at time: SampleTime
    ) -> Rectangle {
        let brought = broughtBack(keyframes, on: clock) { motion, crop in Crop(motion.upright.bringBack(crop.rectangle)) }

        return uprightMotion(on: clock, at: time.frameTime).carry(brought.value(at: time).rectangle)
    }

    func transform(
        on clock: MediaClock,
        at time: SampleTime
    ) -> AffineTransform {
        motion(atMediaTime: clock.mediaTime(atSequenceTime: time.frameTime)).transform
    }

    // MARK: - Private
    private func broughtBack<Value>(
        _ keyframes: FollowedValue<Value>,
        on clock: MediaClock,
        by bringBack: (TrackMotion, Value) -> Value
    ) -> FollowedValue<Value> {
        keyframes.carried(
            keyframe: { value, at in bringBack(motion(atMediaTime: clock.mediaTime(atSequenceTime: at)), value) },
            onTrackFrame: { $0 }
        )
    }

    private func uprightMotion(
        on clock: MediaClock,
        at time: Double
    ) -> TrackMotion {
        motion(atMediaTime: clock.mediaTime(atSequenceTime: time)).upright
    }
}

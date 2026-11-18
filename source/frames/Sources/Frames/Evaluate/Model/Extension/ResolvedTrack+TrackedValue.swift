//
//  ResolvedTrack+TrackedValue.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A tracked clip's geometry at a sequence time, where it is at the instant in the media pixels it follows, its own or
// its parent's: each keyframe is brought back through the motion at the media time the clock of that media gives at
// the keyframe's `at`, and the keyframes are interpolated there by their eases. `transform` then carries the instant
// to the frame shown at a time.
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

    // Each mask's geometry as an area or points are, its radius by the motion's scale, and its feather, in output
    // pixels, as it is.
    func masks(
        of keyframes: [Keyframe<[ResolvedMask]>],
        on clock: MediaClock,
        at time: Double
    ) -> [ResolvedMask] {
        let brought = keyframes.map { keyframe in
            let motion = self.motion(atMediaTime: clock.mediaTime(atSequenceTime: keyframe.at))
            return Keyframe(
                at: keyframe.at,
                value: keyframe.value.map { mask in
                    let geometry: PathGeometry = switch mask.geometry {
                    case let .rect(rectangle, radius):
                        .rect(motion.bringBack(rectangle), radius: radius / motion.scale)

                    case let .ellipse(rectangle):
                        .ellipse(motion.bringBack(rectangle))

                    case let .polyline(points, isClosed):
                        .polyline(points.map { motion.bringBack($0) }, isClosed: isClosed)
                    }

                    return mask.replacing(geometry: geometry)
                },
                ease: keyframe.ease
            )
        }

        return brought.value(at: time)
    }

    // A crop is an upright region of its media, so it takes the motion's move and scale and not its rotation, and the
    // interpolated crop is carried by the motion at the time (FRAMES-12).
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

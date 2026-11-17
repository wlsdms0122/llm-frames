//
//  ResolvedTrack+TrackedValue.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A tracked clip's geometry at a sequence time, where it is at the instant in the media pixels of the storyline entry
// it follows: each keyframe is brought back through the motion at the entry's media time at the keyframe's `at`, and
// the keyframes are interpolated there by their eases. `transform` then carries the instant to the frame the entry
// shows at a time.
extension ResolvedTrack {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func area(
        of keyframes: [Keyframe<Rectangle>],
        on entry: ResolvedStorylineClip,
        at time: Double
    ) -> Rectangle {
        let brought = keyframes.map { keyframe in
            Keyframe(
                at: keyframe.at,
                value: bringBack(keyframe.value, fromMediaTime: entry.mediaTime(at: keyframe.at)),
                ease: keyframe.ease
            )
        }

        return brought.value(at: time)
    }

    func point(
        of keyframes: [Keyframe<Point>],
        on entry: ResolvedStorylineClip,
        at time: Double
    ) -> Point {
        let brought = keyframes.map { keyframe in
            Keyframe(
                at: keyframe.at,
                value: bringBack(keyframe.value, fromMediaTime: entry.mediaTime(at: keyframe.at)),
                ease: keyframe.ease
            )
        }

        return brought.value(at: time)
    }

    func transform(
        on entry: ResolvedStorylineClip,
        at time: Double
    ) -> AffineTransform {
        AffineTransform(carrying: track.motion(atMediaTime: entry.mediaTime(at: time)))
    }

    // MARK: - Private
}

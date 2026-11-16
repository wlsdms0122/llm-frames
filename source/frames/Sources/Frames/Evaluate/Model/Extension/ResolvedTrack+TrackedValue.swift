//
//  ResolvedTrack+TrackedValue.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A tracked clip's geometry at a sequence time, in the media pixels of the storyline entry it follows. Each keyframe is
// where it is at its own time: it is brought back through the motion at the entry's media time at the keyframe's `at`,
// the keyframes are interpolated there by their eases, and the result is carried by the motion at the media time of
// the time asked. An area of a band keeps the full width of its picture and takes the vertical move and scale of its
// height, and a point of a band only the vertical part of the motion.
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

        // A property holds at least one keyframe, so the keyframes always give one.
        let interpolated = KeyframeTrack(keyframes: brought).value(at: time) ?? brought[0].value
        return carry(interpolated, toMediaTime: entry.mediaTime(at: time))
    }

    func point(
        of keyframes: [Keyframe<Point>],
        on entry: ResolvedStorylineClip,
        at time: Double
    ) -> Point {
        let brought = keyframes.map { keyframe in
            Keyframe(
                at: keyframe.at,
                value: bringBack(point: keyframe.value, fromMediaTime: entry.mediaTime(at: keyframe.at)),
                ease: keyframe.ease
            )
        }

        // A property holds at least one keyframe, so the keyframes always give one.
        let interpolated = KeyframeTrack(keyframes: brought).value(at: time) ?? brought[0].value
        return carry(point: interpolated, toMediaTime: entry.mediaTime(at: time))
    }

    // MARK: - Private
    private func bringBack(
        point: Point,
        fromMediaTime time: Double
    ) -> Point {
        let brought = track.motion(atMediaTime: time).bringBack(point)

        return isBand ? Point(x: point.x, y: brought.y) : brought
    }

    private func carry(
        point: Point,
        toMediaTime time: Double
    ) -> Point {
        let carried = track.motion(atMediaTime: time).carry(point)

        return isBand ? Point(x: point.x, y: carried.y) : carried
    }
}

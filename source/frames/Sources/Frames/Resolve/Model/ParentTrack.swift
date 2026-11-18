//
//  ParentTrack.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The track a clip follows in its parent's media (FRAMES-12): the video file followed, and the parent's clock, which
// gives the media time it shows at a sequence time. A tracked clip's keyframes are where they lie on the frame at their
// own `at`, and each is brought back through the motion at the media time there to where it lies at the instant, as
// its evaluation brings them back.
struct ParentTrack: Equatable, Sendable {
    // MARK: - Property
    let track: Track
    let file: MediaFile
    let clock: MediaClock

    // MARK: - Initializer
    init(
        track: Track,
        file: MediaFile,
        clock: MediaClock
    ) {
        self.track = track
        self.file = file
        self.clock = clock
    }

    // MARK: - Public
    func motion(at time: Double) -> TrackMotion {
        track.motion(atMediaTime: clock.mediaTime(atSequenceTime: time))
    }

    func area(_ keyframes: [Keyframe<Rectangle>]) -> [Keyframe<Rectangle>] {
        keyframes.map { keyframe in
            Keyframe(at: keyframe.at, value: motion(at: keyframe.at).bringBack(keyframe.value), ease: keyframe.ease)
        }
    }

    func position(_ keyframes: [Keyframe<Point>]) -> [Keyframe<Point>] {
        keyframes.map { keyframe in
            Keyframe(at: keyframe.at, value: motion(at: keyframe.at).bringBack(keyframe.value), ease: keyframe.ease)
        }
    }

    func points(_ keyframes: [Keyframe<[Point]>]) -> [Keyframe<[Point]>] {
        keyframes.map { keyframe in
            let motion = self.motion(at: keyframe.at)
            return Keyframe(at: keyframe.at, value: keyframe.value.map { motion.bringBack($0) }, ease: keyframe.ease)
        }
    }

    // MARK: - Private
}

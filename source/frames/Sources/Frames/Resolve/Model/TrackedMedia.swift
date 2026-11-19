//
//  TrackedMedia.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A connected or sequence clip's track with its tracked media, its own or its parent's: the video file followed, and
// the clock of that media's clip, which gives the media time it shows at a sequence time. A clip tracked in its
// parent's media has keyframes where they lie on the frame at their own `at`, and each is brought back through the
// motion at the media time there to where it lies at the instant, as its evaluation brings them back.
struct TrackedMedia: Equatable, Sendable {
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

    // A clip area is the named clip's box at each instant evaluated, so it is not brought back.
    func area(_ keyframes: [Keyframe<GeometryArea>]) -> [Keyframe<GeometryArea>] {
        keyframes.map { keyframe in
            let motion = self.motion(at: keyframe.at)
            return Keyframe(at: keyframe.at, value: keyframe.value.map { motion.bringBack($0) }, ease: keyframe.ease)
        }
    }

    func position(_ keyframes: [Keyframe<GeometryPoint>]) -> [Keyframe<GeometryPoint>] {
        keyframes.map { keyframe in
            let motion = self.motion(at: keyframe.at)
            return Keyframe(at: keyframe.at, value: keyframe.value.map { motion.bringBack($0) }, ease: keyframe.ease)
        }
    }

    func points(_ keyframes: [Keyframe<[GeometryPoint]>]) -> [Keyframe<[GeometryPoint]>] {
        keyframes.map { keyframe in
            let motion = self.motion(at: keyframe.at)
            return Keyframe(
                at: keyframe.at,
                value: keyframe.value.map { point in point.map { motion.bringBack($0) } },
                ease: keyframe.ease
            )
        }
    }

    // MARK: - Private
}

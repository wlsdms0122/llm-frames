//
//  TrackedMedia.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A connected or sequence clip's track with its tracked media, its own or its parent's: the video file followed, and
// the clock of that media's clip, which gives the media time it shows at a sequence time. A clip tracked in its
// parent's media has keyframes where they lie on the frame at their own `at`, and each is brought back through the
// motion at the media time there to where it lies on the track's frame, as its evaluation brings them back. A value
// true on the track's frame is not brought back.
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

    func homography(at time: Double) -> Homography? {
        track.homography(atMediaTime: clock.mediaTime(atSequenceTime: time))
    }

    // A clip area is the named clip's box at each instant evaluated, so it is not brought back.
    func area(_ keyframes: FollowedValue<GeometryArea>) -> FollowedValue<GeometryArea> {
        broughtBack(keyframes) { motion, area in area.map { motion.bringBack($0) } }
    }

    func position(_ keyframes: FollowedValue<GeometryPoint>) -> FollowedValue<GeometryPoint> {
        broughtBack(keyframes) { motion, point in point.map { motion.bringBack($0) } }
    }

    func points(_ keyframes: FollowedValue<[GeometryPoint]>) -> FollowedValue<[GeometryPoint]> {
        broughtBack(keyframes) { motion, points in points.map { point in point.map { motion.bringBack($0) } } }
    }

    // MARK: - Private
    private func broughtBack<Value>(
        _ keyframes: FollowedValue<Value>,
        by bringBack: (TrackMotion, Value) -> Value
    ) -> FollowedValue<Value> {
        keyframes.carried(keyframe: { value, at in bringBack(motion(at: at), value) }, onTrackFrame: { $0 })
    }
}

//
//  Track.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What the tracker or track data followed: `target` is the target's quad before padding on the track's frame at
// `mediaTime`, and `samples` its quad and fitted motion on every frame followed, in time order. A time before the first
// frame or after the last holds the nearest one, as a handle past the end of the media holds its edge frame.
struct Track: Equatable, Sendable {
    // MARK: - Property
    let target: Quad
    let mediaTime: Double
    let samples: [TrackSample]

    // MARK: - Initializer
    init(
        target: Quad,
        mediaTime: Double,
        samples: [TrackSample]
    ) {
        self.target = target
        self.mediaTime = mediaTime
        self.samples = samples
    }

    // The motion fitted to each frame the tracker reported.
    init(
        target: Quad,
        mediaTime: Double,
        frames: [TrackedFrame]
    ) {
        self.init(
            target: target,
            mediaTime: mediaTime,
            samples: frames.map { frame in
                TrackSample(time: frame.time, quad: frame.quad, motion: TrackMotion(from: target, to: frame.quad))
            }
        )
    }

    // MARK: - Public
    // The motion on the frame shown at the media time: the last frame followed at or before it, compared to the
    // microsecond as the frame drawn is picked, so the motion and the picture come from the same frame.
    func motion(atMediaTime time: Double) -> TrackMotion {
        guard let first = samples.first else { return .identity }

        return (samples.last { $0.time.roundedTime <= time.roundedTime } ?? first).motion
    }

    // The homography on the same frame, H(target → quad) (FRAMES-12 The track), nil where that quad is not strictly
    // convex, which no frame followed has.
    func homography(atMediaTime time: Double) -> Homography? {
        guard let first = samples.first else { return .identity }

        return Homography(from: target, to: (samples.last { $0.time.roundedTime <= time.roundedTime } ?? first).quad)
    }

    // MARK: - Private
}

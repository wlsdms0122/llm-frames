//
//  TrackSample.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// One frame of a track: the target's quad on the frame at media time `time` and the motion fitted to it from the
// target's quad at the instant.
struct TrackSample: Equatable, Sendable {
    // MARK: - Property
    let time: Double
    let quad: Quad
    let motion: TrackMotion

    // MARK: - Initializer
    init(
        time: Double,
        quad: Quad,
        motion: TrackMotion
    ) {
        self.time = time
        self.quad = quad
        self.motion = motion
    }

    // MARK: - Public
    // MARK: - Private
}

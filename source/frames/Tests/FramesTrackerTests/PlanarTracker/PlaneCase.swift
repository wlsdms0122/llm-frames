//
//  PlaneCase.swift
//  FramesTrackerTests
//
//  Created by JSilver on 11/22/26.
//

import Testing

// A planar tracker's video of a poster moving by `motion`, followed from frame `start`, whose corners may be off by
// `tolerance` media pixels on every frame.
struct PlaneCase: Sendable, CustomTestStringConvertible {
    // MARK: - Property
    let motion: PlaneMotion
    let start: Int
    let tolerance: Double

    var testDescription: String {
        "\(motion) from frame \(start)"
    }

    // MARK: - Initializer
    init(
        motion: PlaneMotion,
        start: Int,
        tolerance: Double
    ) {
        self.motion = motion
        self.start = start
        self.tolerance = tolerance
    }

    // MARK: - Public
    // MARK: - Private
}

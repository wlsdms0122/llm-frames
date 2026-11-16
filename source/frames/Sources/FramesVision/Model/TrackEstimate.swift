//
//  TrackEstimate.swift
//  FramesVision
//
//  Created by JSilver on 11/16/26.
//

import CoreGraphics

// Where the track points lie on a frame, the target's scale there against its own frame, and the lower of the points'
// correlations.
struct TrackEstimate: Sendable {
    // MARK: - Property
    let points: [CGPoint]
    let scale: Double
    let correlation: Double

    // MARK: - Initializer
    init(
        points: [CGPoint],
        scale: Double,
        correlation: Double
    ) {
        self.points = points
        self.scale = scale
        self.correlation = correlation
    }

    // MARK: - Public
    // MARK: - Private
}

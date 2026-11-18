//
//  TrackEstimate.swift
//  FramesPointTracker
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// Where the track points lie on a frame, and the lower of the points' correlations.
struct TrackEstimate: Sendable {
    // MARK: - Property
    let points: [CGPoint]
    let correlation: Double

    // MARK: - Initializer
    init(
        points: [CGPoint],
        correlation: Double
    ) {
        self.points = points
        self.correlation = correlation
    }

    // MARK: - Public
    // MARK: - Private
}

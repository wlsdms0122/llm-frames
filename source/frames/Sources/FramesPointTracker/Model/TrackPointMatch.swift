//
//  TrackPointMatch.swift
//  FramesPointTracker
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// Where a track point lies on a frame, and how well the frame there matches its feature, as a correlation from -1
// to 1.
struct TrackPointMatch: Sendable {
    // MARK: - Property
    let point: CGPoint
    let correlation: Double

    // MARK: - Initializer
    init(
        point: CGPoint,
        correlation: Double
    ) {
        self.point = point
        self.correlation = correlation
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  Double+Geometric.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

import Foundation

extension Double {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // A value between two positive ends at an even ratio, so equal steps of progress multiply it by equal factors. It
    // stays above 0 at any progress, an overshooting ease's included.
    static func geometric(
        from start: Double,
        to end: Double,
        progress: Double
    ) -> Double {
        exp(.interpolate(from: log(start), to: log(end), progress: progress))
    }

    // MARK: - Private
}

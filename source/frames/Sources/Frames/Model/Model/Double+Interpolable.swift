//
//  Double+Interpolable.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

extension Double: Interpolable {
    static func interpolate(
        from start: Double,
        to end: Double,
        progress: Double
    ) -> Double {
        start + (end - start) * progress
    }
}

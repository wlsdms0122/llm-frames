//
//  Double+TimeResolution.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Times are measured to the microsecond: compared rounded to the nearest one, so floating point noise in a computed
// time does not move it across a frame's timestamp. A microsecond is far below a frame at any rate.
extension Double {
    // MARK: - Property
    static let timeResolution = 1e-6

    // The time rounded to the nearest microsecond.
    var roundedTime: Double {
        (self * 1_000_000).rounded() / 1_000_000
    }
}

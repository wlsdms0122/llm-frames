//
//  JSONValue+Measure.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Machine output writes every position in pixels and every opacity to the nearest millionth, as it writes times to
// the microsecond, so the floating point noise of a turn or a product stays out of it.
extension JSONValue {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    static func measure(_ value: Double) -> JSONValue {
        .number((value * 1_000_000).rounded() / 1_000_000)
    }

    // MARK: - Private
}

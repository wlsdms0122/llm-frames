//
//  SpanKey.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct SpanKey: Equatable, Sendable {
    // MARK: - Property
    let t: Double
    let values: [MotionProperty: Double]

    // MARK: - Initializer
    init(t: Double, values: [MotionProperty: Double]) {
        self.t = t
        self.values = values
    }

    // MARK: - Public
    // MARK: - Private
}

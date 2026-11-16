//
//  Motion.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The value of every motion property at one instant of a span.
struct Motion: Equatable, Sendable {
    // MARK: - Property
    let values: [MotionProperty: Double]

    // MARK: - Initializer
    init(values: [MotionProperty: Double] = [:]) {
        self.values = values
    }

    // MARK: - Public
    func value(of property: MotionProperty) -> Double {
        values[property] ?? property.defaultValue
    }

    // MARK: - Private
}

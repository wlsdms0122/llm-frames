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
    // An ease that overshoots carries opacity past its keys, and an opacity is drawn from 0 to 1.
    func value(of property: MotionProperty) -> Double {
        let value = values[property] ?? property.defaultValue
        guard property == .opacity else { return value }

        return min(max(value, 0), 1)
    }

    // MARK: - Private
}

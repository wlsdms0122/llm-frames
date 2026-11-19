//
//  GeometricLeafValue.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A timed leaf that interpolates geometrically, each number on its own. Its numbers are above 0, as the leaf's domain
// checks them; a colour moves as a linear leaf's does.
struct GeometricLeafValue: Interpolable {
    // MARK: - Property
    let value: LeafValue

    // MARK: - Initializer
    init(_ value: LeafValue) {
        self.value = value
    }

    // MARK: - Public
    static func interpolate(
        from start: GeometricLeafValue,
        to end: GeometricLeafValue,
        progress: Double
    ) -> GeometricLeafValue {
        switch (start.value, end.value) {
        case let (.number(start), .number(end)):
            GeometricLeafValue(.number(.geometric(from: start, to: end, progress: progress)))

        case let (.numbers(start), .numbers(end)):
            GeometricLeafValue(.numbers(zip(start, end).map { start, end in
                .geometric(from: start, to: end, progress: progress)
            }))

        default:
            GeometricLeafValue(.interpolate(from: start.value, to: end.value, progress: progress))
        }
    }

    // MARK: - Private
}

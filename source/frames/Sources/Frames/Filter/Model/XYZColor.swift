//
//  XYZColor.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// CIE 1931 XYZ tristimulus values.
package struct XYZColor: Equatable, Sendable {
    // MARK: - Property
    package let x: Double
    package let y: Double
    package let z: Double

    // MARK: - Initializer
    package init(
        x: Double,
        y: Double,
        z: Double
    ) {
        self.x = x
        self.y = y
        self.z = z
    }

    // MARK: - Public
    // MARK: - Private
}

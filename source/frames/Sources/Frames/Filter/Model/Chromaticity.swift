//
//  Chromaticity.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// CIE 1931 xy chromaticity coordinates.
package struct Chromaticity: Equatable, Sendable {
    // MARK: - Property
    package let x: Double
    package let y: Double

    // MARK: - Initializer
    package init(
        x: Double,
        y: Double
    ) {
        self.x = x
        self.y = y
    }

    package init(xyz: XYZColor) {
        let sum = xyz.x + xyz.y + xyz.z

        self.init(x: xyz.x / sum, y: xyz.y / sum)
    }

    // MARK: - Public
    // MARK: - Private
}

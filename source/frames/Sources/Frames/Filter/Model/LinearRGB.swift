//
//  LinearRGB.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// A colour in linear light on the sRGB primaries with the D65 white point.
package struct LinearRGB: Equatable, Sendable {
    // MARK: - Property
    package let red: Double
    package let green: Double
    package let blue: Double

    // MARK: - Initializer
    package init(
        red: Double,
        green: Double,
        blue: Double
    ) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    // The XYZ to linear sRGB matrix of IEC 61966-2-1.
    package init(xyz: XYZColor) {
        self.init(
            red: 3.2406 * xyz.x - 1.5372 * xyz.y - 0.4986 * xyz.z,
            green: -0.9689 * xyz.x + 1.8758 * xyz.y + 0.0415 * xyz.z,
            blue: 0.0557 * xyz.x - 0.2040 * xyz.y + 1.0570 * xyz.z
        )
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  ColorMatchingFunction.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// The CIE 1931 2° colour matching functions, by the multi-lobe Gaussian fit of Wyman, Sloan and Shirley (2013),
// "Simple Analytic Approximations to the CIE XYZ Color Matching Functions".
package struct ColorMatchingFunction: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    package init() {}

    // MARK: - Public
    // `wavelength` is in nanometres.
    package func value(at wavelength: Double) -> XYZColor {
        XYZColor(
            x: 1.056 * lobe(wavelength, mean: 599.8, below: 37.9, above: 31.0)
                + 0.362 * lobe(wavelength, mean: 442.0, below: 16.0, above: 26.7)
                - 0.065 * lobe(wavelength, mean: 501.1, below: 20.4, above: 26.2),
            y: 0.821 * lobe(wavelength, mean: 568.8, below: 46.9, above: 40.5)
                + 0.286 * lobe(wavelength, mean: 530.9, below: 16.3, above: 31.1),
            z: 1.217 * lobe(wavelength, mean: 437.0, below: 11.8, above: 36.0)
                + 0.681 * lobe(wavelength, mean: 459.0, below: 26.0, above: 13.8)
        )
    }

    // MARK: - Private
    // A Gaussian with one standard deviation below its mean and another above it.
    private func lobe(
        _ wavelength: Double,
        mean: Double,
        below: Double,
        above: Double
    ) -> Double {
        let deviation = (wavelength - mean) / (wavelength < mean ? below : above)

        return exp(-0.5 * deviation * deviation)
    }
}

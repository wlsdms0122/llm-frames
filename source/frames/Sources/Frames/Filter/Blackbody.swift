//
//  Blackbody.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// A blackbody radiator at `temperature` kelvin.
package struct Blackbody: Sendable {
    // MARK: - Property
    package let temperature: Double

    // The second radiation constant hc / k, in metre kelvin.
    private let secondRadiationConstant = 1.438776877e-2

    // MARK: - Initializer
    package init(temperature: Double) {
        self.temperature = temperature
    }

    // MARK: - Public
    // Its colour for the CIE 1931 2° observer, Planck's law integrated against the colour matching functions at 1 nm
    // from 360 to 830 nm, scaled to Y = 1.
    package func xyz() -> XYZColor {
        let observer = ColorMatchingFunction()
        var x = 0.0
        var y = 0.0
        var z = 0.0
        for wavelength in 360...830 {
            let radiance = spectralRadiance(at: Double(wavelength))
            let match = observer.value(at: Double(wavelength))
            x += radiance * match.x
            y += radiance * match.y
            z += radiance * match.z
        }

        return XYZColor(x: x / y, y: 1, z: z / y)
    }

    // Planck's law at `wavelength` nanometres, without the constant factor 2hc², which the scaling to Y = 1 removes.
    package func spectralRadiance(at wavelength: Double) -> Double {
        let metres = wavelength * 1e-9

        return 1 / (pow(metres, 5) * (exp(secondRadiationConstant / (metres * temperature)) - 1))
    }

    // MARK: - Private
}

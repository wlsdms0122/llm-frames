//
//  PerceptualQuantizer.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

import Foundation

// The PQ transfer of SMPTE ST 2084, as BT.2100 gives it, between display light in cd/m² and encoded values, each
// channel on its own. Light is clipped to 0 to 10000 cd/m² and an encoded value to 0 to 1, the range PQ names light
// for, so every value gives a finite one.
package struct PerceptualQuantizer: Equatable, Sendable {
    // MARK: - Property
    package static let peakLuminance = 10000.0

    private static let m1 = 2610.0 / 16384
    private static let m2 = 2523.0 / 4096 * 128
    private static let c1 = 3424.0 / 4096
    private static let c2 = 2413.0 / 4096 * 32
    private static let c3 = 2392.0 / 4096 * 32

    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    // The inverse EOTF.
    package func encoded(displayLight: Double) -> Double {
        let y = pow(min(max(displayLight, 0), Self.peakLuminance) / Self.peakLuminance, Self.m1)

        return pow((Self.c1 + Self.c2 * y) / (1 + Self.c3 * y), Self.m2)
    }

    // The EOTF.
    package func displayLight(encoded: Double) -> Double {
        let power = pow(min(max(encoded, 0), 1), 1 / Self.m2)

        return Self.peakLuminance * pow(max(power - Self.c1, 0) / (Self.c2 - Self.c3 * power), 1 / Self.m1)
    }

    package func encoded(displayLight: RGB) -> RGB {
        displayLight.map { encoded(displayLight: $0) }
    }

    package func displayLight(encoded: RGB) -> RGB {
        encoded.map { displayLight(encoded: $0) }
    }

    // MARK: - Private
}

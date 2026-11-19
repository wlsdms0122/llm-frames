//
//  HybridLogGamma.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

import Foundation

// The HLG transfer of ARIB STD-B67, as BT.2100 gives it, at a nominal peak of 1000 cd/m² and a black of 0, so the
// system gamma is 1.2 and the black lift 0. Scene light is 0 to 1 and display light in cd/m², both on BT.2020
// primaries. An encoded value is clipped to 0 to 1 and display light to 0 to the nominal peak, the range HLG names
// light for.
package struct HybridLogGamma: Equatable, Sendable {
    // MARK: - Property
    package static let nominalPeakLuminance = 1000.0

    private static let a = 0.17883277
    private static let b = 1 - 4 * a
    private static let c = 0.5 - a * log(4 * a)
    private static let systemGamma = 1.2

    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    // The OETF.
    package func encoded(sceneLight: Double) -> Double {
        let light = max(sceneLight, 0)
        guard light > 1.0 / 12 else { return (3 * light).squareRoot() }

        return Self.a * log(12 * light - Self.b) + Self.c
    }

    // The inverse OETF.
    package func sceneLight(encoded: Double) -> Double {
        let value = min(max(encoded, 0), 1)
        guard value > 0.5 else { return value * value / 3 }

        return (exp((value - Self.c) / Self.a) + Self.b) / 12
    }

    // The OOTF, 0 where the scene light's luminance is 0.
    package func displayLight(sceneLight: RGB) -> RGB {
        let luminance = Self.luminance(of: sceneLight)
        guard luminance > 0 else { return RGB(red: 0, green: 0, blue: 0) }

        return sceneLight.scaled(by: Self.nominalPeakLuminance * pow(luminance, Self.systemGamma - 1))
    }

    // The inverse OOTF, 0 where the display light's luminance is 0.
    package func sceneLight(displayLight: RGB) -> RGB {
        let light = displayLight.clipped(to: 0...Self.nominalPeakLuminance)
        let luminance = Self.luminance(of: light)
        guard luminance > 0 else { return RGB(red: 0, green: 0, blue: 0) }

        let ratio = pow(luminance / Self.nominalPeakLuminance, (1 - Self.systemGamma) / Self.systemGamma)
        return light.scaled(by: ratio / Self.nominalPeakLuminance)
    }

    // Display light of an encoded value: the OOTF of the inverse OETF.
    package func displayLight(encoded: RGB) -> RGB {
        displayLight(sceneLight: encoded.map { sceneLight(encoded: $0) })
    }

    // The encoded value of display light: the OETF of the inverse OOTF.
    package func encoded(displayLight: RGB) -> RGB {
        sceneLight(displayLight: displayLight).map { encoded(sceneLight: $0) }
    }

    // MARK: - Private
    // The luminance of light on BT.2020 primaries.
    private static func luminance(of light: RGB) -> Double {
        0.2627 * light.red + 0.6780 * light.green + 0.0593 * light.blue
    }
}

//
//  ColorPrimaries.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

// The chromaticities of a colour space's red, green and blue, each with the D65 white point.
package enum ColorPrimaries: Equatable, Sendable {
    case bt709
    case p3D65
    case bt2020

    // MARK: - Property
    package static let whitePoint = Chromaticity(x: 0.3127, y: 0.3290)

    package var red: Chromaticity {
        switch self {
        case .bt709:
            Chromaticity(x: 0.640, y: 0.330)

        case .p3D65:
            Chromaticity(x: 0.680, y: 0.320)

        case .bt2020:
            Chromaticity(x: 0.708, y: 0.292)
        }
    }

    package var green: Chromaticity {
        switch self {
        case .bt709:
            Chromaticity(x: 0.300, y: 0.600)

        case .p3D65:
            Chromaticity(x: 0.265, y: 0.690)

        case .bt2020:
            Chromaticity(x: 0.170, y: 0.797)
        }
    }

    package var blue: Chromaticity {
        switch self {
        case .bt709, .p3D65:
            Chromaticity(x: 0.150, y: 0.060)

        case .bt2020:
            Chromaticity(x: 0.131, y: 0.046)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

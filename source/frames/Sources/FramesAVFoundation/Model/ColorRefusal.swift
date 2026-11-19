//
//  ColorRefusal.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/20/26.
//

import Frames

// Why no fixed formula converts a picture's colour (FRAMES-26 Media).
enum ColorRefusal: Error, Equatable, Sendable {
    // An ICC profile that holds its transform in lookup tables, or is no matrix and tone-curve profile.
    case lookupTableProfile
    // Code points one of which H.273 reserves.
    case reservedCodePoints(CodePoints)

    // MARK: - Property
    var reason: String {
        switch self {
        case .lookupTableProfile:
            "its ICC profile is LUT-based"

        case let .reservedCodePoints(codePoints):
            "its colour code points (primaries \(codePoints.colorPrimaries), transfer "
                + "\(codePoints.transferCharacteristics), matrix \(codePoints.matrixCoefficients)) are not all defined"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

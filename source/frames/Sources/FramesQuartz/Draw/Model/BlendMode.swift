//
//  BlendMode.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

// The blend modes of W3C Compositing and Blending Level 1 by their names in a display list, each with the colour
// kernel that composites it.
enum BlendMode: String, CaseIterable, Sendable {
    case normal
    case multiply
    case screen
    case overlay
    case darken
    case lighten
    case colorDodge = "color-dodge"
    case colorBurn = "color-burn"
    case hardLight = "hard-light"
    case softLight = "soft-light"
    case difference
    case exclusion
    case plusLighter = "plus-lighter"
    case hue
    case saturation
    case color
    case luminosity

    // MARK: - Property
    var kernelName: String {
        switch self {
        case .normal:
            "blendNormal"

        case .multiply:
            "blendMultiply"

        case .screen:
            "blendScreen"

        case .overlay:
            "blendOverlay"

        case .darken:
            "blendDarken"

        case .lighten:
            "blendLighten"

        case .colorDodge:
            "blendColorDodge"

        case .colorBurn:
            "blendColorBurn"

        case .hardLight:
            "blendHardLight"

        case .softLight:
            "blendSoftLight"

        case .difference:
            "blendDifference"

        case .exclusion:
            "blendExclusion"

        case .plusLighter:
            "blendPlusLighter"

        case .hue:
            "blendHue"

        case .saturation:
            "blendSaturation"

        case .color:
            "blendColor"

        case .luminosity:
            "blendLuminosity"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

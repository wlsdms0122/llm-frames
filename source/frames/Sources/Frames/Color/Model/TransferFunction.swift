//
//  TransferFunction.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

import Foundation

// An SDR transfer between a space's linear value and its encoded value, on all real numbers. `sRGB` and `bt1886` are
// the transfers of the table's spaces, and the others those of ITU-T H.273's transfer characteristics outside it, each
// encoded by the function H.273 gives and decoded by its inverse. A function H.273 defines for light from 0 up is
// carried to negative values with the sign kept, and a logarithmic one gives 0 below its range.
package enum TransferFunction: Hashable, Sendable {
    // The sRGB transfer of IEC 61966-2-1, extended to all real numbers as CSS Color 4 extends it. It is also the
    // transfer between the linear and the encoded form of a working value.
    case sRGB
    // The inverse of the BT.1886 EOTF at a white of 1 and a black of 0, and that EOTF, which `rec709` and `rec2020`
    // take both ways.
    case bt1886
    // An assumed display gamma: 2.2 for transfer characteristics 4, and 2.8 for 5.
    case gamma(Double)
    // Transfer characteristics 7, SMPTE ST 240.
    case smpte240M
    // Transfer characteristics 8, the identity.
    case linear
    // Transfer characteristics 9, a logarithm over a range of 100 to 1.
    case logarithmic100
    // Transfer characteristics 10, a logarithm over a range of 100 × √10 to 1.
    case logarithmic316
    // Transfer characteristics 11, IEC 61966-2-4: the BT.709 OETF taken to negative values with the sign kept.
    case xvYCC
    // Transfer characteristics 12, the extended colour gamut of BT.1361.
    case bt1361
    // Transfer characteristics 17, SMPTE ST 428-1.
    case smpte428

    // MARK: - Property
    private static let alpha = 1.099296826809442
    private static let beta = 0.018053968510807
    private static let bt1361Lower = 0.0045

    // MARK: - Initializer
    // The SDR transfer H.273 gives for the code point: 1, 6, 14 and 15 decoded as BT.1886 and 13 as sRGB, as the table
    // reads them. Nil for PQ (16), HLG (18) and a value H.273 reserves. 2 (unspecified) is not a transfer: a caller
    // takes it as `srgb`'s.
    package init?(transferCharacteristics codePoint: Int) {
        switch codePoint {
        case 1, 6, 14, 15:
            self = .bt1886

        case 4:
            self = .gamma(2.2)

        case 5:
            self = .gamma(2.8)

        case 7:
            self = .smpte240M

        case 8:
            self = .linear

        case 9:
            self = .logarithmic100

        case 10:
            self = .logarithmic316

        case 11:
            self = .xvYCC

        case 12:
            self = .bt1361

        case 13:
            self = .sRGB

        case 17:
            self = .smpte428

        default:
            return nil
        }
    }

    // MARK: - Public
    package func encode(_ linear: Double) -> Double {
        let magnitude = abs(linear)
        let sign = linear < 0 ? -1.0 : 1.0
        let alpha = Self.alpha
        let beta = Self.beta

        switch self {
        case .sRGB:
            guard magnitude > 0.0031308 else { return 12.92 * linear }

            return sign * (1.055 * pow(magnitude, 1 / 2.4) - 0.055)

        case .bt1886:
            return sign * pow(magnitude, 1 / 2.4)

        case let .gamma(gamma):
            return sign * pow(magnitude, 1 / gamma)

        case .smpte240M:
            guard magnitude >= 0.0228 else { return 4 * linear }

            return sign * (1.1115 * pow(magnitude, 0.45) - 0.1115)

        case .linear:
            return linear

        case .logarithmic100:
            guard linear >= 0.01 else { return 0 }

            return 1 + log10(linear) / 2

        case .logarithmic316:
            guard linear >= 10.0.squareRoot() / 1000 else { return 0 }

            return 1 + log10(linear) / 2.5

        case .xvYCC:
            guard magnitude >= beta else { return 4.5 * linear }

            return sign * (alpha * pow(magnitude, 0.45) - (alpha - 1))

        case .bt1361:
            if linear >= beta { return alpha * pow(linear, 0.45) - (alpha - 1) }
            if linear >= -Self.bt1361Lower { return 4.5 * linear }

            return -(alpha * pow(-4 * linear, 0.45) - (alpha - 1)) / 4

        case .smpte428:
            return sign * pow(48 * magnitude / 52.37, 1 / 2.6)
        }
    }

    package func decode(_ encoded: Double) -> Double {
        let magnitude = abs(encoded)
        let sign = encoded < 0 ? -1.0 : 1.0
        let alpha = Self.alpha
        let beta = Self.beta

        switch self {
        case .sRGB:
            guard magnitude > 0.04045 else { return encoded / 12.92 }

            return sign * pow((magnitude + 0.055) / 1.055, 2.4)

        case .bt1886:
            return sign * pow(magnitude, 2.4)

        case let .gamma(gamma):
            return sign * pow(magnitude, gamma)

        case .smpte240M:
            guard magnitude >= 4 * 0.0228 else { return encoded / 4 }

            return sign * pow((magnitude + 0.1115) / 1.1115, 1 / 0.45)

        case .linear:
            return encoded

        case .logarithmic100:
            guard encoded > 0 else { return 0 }

            return pow(10, 2 * (encoded - 1))

        case .logarithmic316:
            guard encoded > 0 else { return 0 }

            return pow(10, 2.5 * (encoded - 1))

        case .xvYCC:
            guard magnitude >= 4.5 * beta else { return encoded / 4.5 }

            return sign * pow((magnitude + alpha - 1) / alpha, 1 / 0.45)

        case .bt1361:
            if encoded >= 4.5 * beta { return pow((encoded + alpha - 1) / alpha, 1 / 0.45) }
            if encoded >= -4.5 * Self.bt1361Lower { return encoded / 4.5 }

            return -pow((-4 * encoded + alpha - 1) / alpha, 1 / 0.45) / 4

        case .smpte428:
            return sign * 52.37 / 48 * pow(magnitude, 2.6)
        }
    }

    package func encode(_ linear: RGB) -> RGB {
        linear.map(encode)
    }

    package func decode(_ encoded: RGB) -> RGB {
        encoded.map(decode)
    }

    // MARK: - Private
}

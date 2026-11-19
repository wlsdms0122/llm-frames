//
//  TransferFunction.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

import Foundation

// An SDR transfer between a space's linear value and its encoded value, on all real numbers with the sign kept.
package enum TransferFunction: Equatable, Sendable {
    // The sRGB transfer of IEC 61966-2-1, extended to all real numbers as CSS Color 4 extends it. It is also the
    // transfer between the linear and the encoded form of a working value.
    case sRGB
    // The BT.2020 transfer, with the constants CSS Color 4 gives.
    case bt2020
    // The inverse of the BT.1886 EOTF at a white of 1 and a black of 0, and that EOTF.
    case bt1886

    // MARK: - Property
    private static let bt2020Alpha = 1.09929682680944
    private static let bt2020Beta = 0.018053968510807

    // MARK: - Initializer
    // MARK: - Public
    package func encode(_ linear: Double) -> Double {
        let magnitude = abs(linear)
        let sign = linear < 0 ? -1.0 : 1.0

        switch self {
        case .sRGB:
            guard magnitude > 0.0031308 else { return 12.92 * linear }

            return sign * (1.055 * pow(magnitude, 1 / 2.4) - 0.055)

        case .bt2020:
            guard magnitude >= Self.bt2020Beta else { return 4.5 * linear }

            return sign * (Self.bt2020Alpha * pow(magnitude, 0.45) - (Self.bt2020Alpha - 1))

        case .bt1886:
            return sign * pow(magnitude, 1 / 2.4)
        }
    }

    package func decode(_ encoded: Double) -> Double {
        let magnitude = abs(encoded)
        let sign = encoded < 0 ? -1.0 : 1.0

        switch self {
        case .sRGB:
            guard magnitude > 0.04045 else { return encoded / 12.92 }

            return sign * pow((magnitude + 0.055) / 1.055, 2.4)

        case .bt2020:
            guard magnitude >= 4.5 * Self.bt2020Beta else { return encoded / 4.5 }

            return sign * pow((magnitude + Self.bt2020Alpha - 1) / Self.bt2020Alpha, 1 / 0.45)

        case .bt1886:
            return sign * pow(magnitude, 2.4)
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

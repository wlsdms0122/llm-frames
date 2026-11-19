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
    // The inverse of the BT.1886 EOTF at a white of 1 and a black of 0, and that EOTF, which `rec709` and `rec2020`
    // take both ways.
    case bt1886

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    package func encode(_ linear: Double) -> Double {
        let magnitude = abs(linear)
        let sign = linear < 0 ? -1.0 : 1.0

        switch self {
        case .sRGB:
            guard magnitude > 0.0031308 else { return 12.92 * linear }

            return sign * (1.055 * pow(magnitude, 1 / 2.4) - 0.055)

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

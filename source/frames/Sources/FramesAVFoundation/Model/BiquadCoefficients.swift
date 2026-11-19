//
//  BiquadCoefficients.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import Frames

// A biquad's coefficients by the RBJ Audio EQ Cookbook, divided by its a0, so a filter computes
// y[n] = b0 x[n] + b1 x[n-1] + b2 x[n-2] - a1 y[n-1] - a2 y[n-2].
struct BiquadCoefficients: Equatable, Sendable {
    // MARK: - Property
    let b0: Double
    let b1: Double
    let b2: Double
    let a1: Double
    let a2: Double

    // MARK: - Initializer
    // `gain` in dB is used by the shelves and the peak only.
    init(
        type: MixBandType,
        frequency: Double,
        gain: Double,
        q: Double,
        sampleRate: Double
    ) {
        let omega = 2 * Double.pi * frequency / sampleRate
        let cosine = cos(omega)
        let alpha = sin(omega) / (2 * q)
        let amplitude = pow(10, gain / 40)
        let shelf = 2 * amplitude.squareRoot() * alpha

        let raw: [Double] = switch type {
        case .lowPass:
            [(1 - cosine) / 2, 1 - cosine, (1 - cosine) / 2, 1 + alpha, -2 * cosine, 1 - alpha]

        case .highPass:
            [(1 + cosine) / 2, -(1 + cosine), (1 + cosine) / 2, 1 + alpha, -2 * cosine, 1 - alpha]

        case .peak:
            [
                1 + alpha * amplitude,
                -2 * cosine,
                1 - alpha * amplitude,
                1 + alpha / amplitude,
                -2 * cosine,
                1 - alpha / amplitude
            ]

        case .lowShelf:
            [
                amplitude * ((amplitude + 1) - (amplitude - 1) * cosine + shelf),
                2 * amplitude * ((amplitude - 1) - (amplitude + 1) * cosine),
                amplitude * ((amplitude + 1) - (amplitude - 1) * cosine - shelf),
                (amplitude + 1) + (amplitude - 1) * cosine + shelf,
                -2 * ((amplitude - 1) + (amplitude + 1) * cosine),
                (amplitude + 1) + (amplitude - 1) * cosine - shelf
            ]

        case .highShelf:
            [
                amplitude * ((amplitude + 1) + (amplitude - 1) * cosine + shelf),
                -2 * amplitude * ((amplitude - 1) + (amplitude + 1) * cosine),
                amplitude * ((amplitude + 1) + (amplitude - 1) * cosine - shelf),
                (amplitude + 1) - (amplitude - 1) * cosine + shelf,
                2 * ((amplitude - 1) - (amplitude + 1) * cosine),
                (amplitude + 1) - (amplitude - 1) * cosine - shelf
            ]
        }
        let a0 = raw[3]

        self.b0 = raw[0] / a0
        self.b1 = raw[1] / a0
        self.b2 = raw[2] / a0
        self.a1 = raw[4] / a0
        self.a2 = raw[5] / a0
    }

    // MARK: - Public
    // MARK: - Private
}

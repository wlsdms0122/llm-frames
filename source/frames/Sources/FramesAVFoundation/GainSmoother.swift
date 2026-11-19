//
//  GainSmoother.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/19/26.
//

import Foundation

// A branching peak detector on a gain in dB:
// g[n] = β g[n-1] + (1 - β) c[n] with β = exp(-1 / (τ × Fs)). The caller picks τ, the attack or the release, by its
// own branch. A τ an ease carries to 0 or below follows the target at once, the limit of β as τ goes to 0.
struct GainSmoother: Sendable {
    // MARK: - Property
    private(set) var gain: Double

    private let sampleRate: Double
    private var timeConstant = Double.nan
    private var coefficient: Double = 0

    // MARK: - Initializer
    init(
        gain: Double,
        sampleRate: Double
    ) {
        self.gain = gain
        self.sampleRate = sampleRate
    }

    // MARK: - Public
    mutating func step(
        toward target: Double,
        timeConstant: Double
    ) {
        if timeConstant != self.timeConstant {
            self.timeConstant = timeConstant
            coefficient = timeConstant > 0 ? exp(-1 / (timeConstant * sampleRate)) : 0
        }
        gain = coefficient * gain + (1 - coefficient) * target
    }

    // MARK: - Private
}

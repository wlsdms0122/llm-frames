//
//  MixLimiter.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A limiter's parameters with its defaults written: `gain` in dB, `ceiling` in dBTP, `lookahead` in seconds, static,
// and `release` in seconds.
package struct MixLimiter: Equatable, Sendable {
    // MARK: - Property
    package let gain: MixValue
    package let ceiling: MixValue
    package let lookahead: Double
    package let release: MixValue

    // MARK: - Initializer
    package init(
        gain: MixValue,
        ceiling: MixValue,
        lookahead: Double,
        release: MixValue
    ) {
        self.gain = gain
        self.ceiling = ceiling
        self.lookahead = lookahead
        self.release = release
    }

    // MARK: - Public
    // MARK: - Private
}

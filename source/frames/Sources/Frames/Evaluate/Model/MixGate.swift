//
//  MixGate.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A noise gate's parameters with its defaults written: `threshold` in dBFS, `range` in dB, `attack`, `hold` and
// `release` in seconds.
package struct MixGate: Equatable, Sendable {
    // MARK: - Property
    package let threshold: MixValue
    package let range: MixValue
    package let attack: MixValue
    package let hold: MixValue
    package let release: MixValue

    // MARK: - Initializer
    package init(
        threshold: MixValue,
        range: MixValue,
        attack: MixValue,
        hold: MixValue,
        release: MixValue
    ) {
        self.threshold = threshold
        self.range = range
        self.attack = attack
        self.hold = hold
        self.release = release
    }

    // MARK: - Public
    // MARK: - Private
}

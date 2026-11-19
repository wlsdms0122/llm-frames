//
//  MixCompressor.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A compressor's parameters with its defaults written: `threshold` in dBFS, `knee` and `makeup` in dB, `attack` and
// `release` in seconds.
package struct MixCompressor: Equatable, Sendable {
    // MARK: - Property
    package let threshold: MixValue
    package let ratio: MixValue
    package let knee: MixValue
    package let attack: MixValue
    package let release: MixValue
    package let makeup: MixValue

    // MARK: - Initializer
    package init(
        threshold: MixValue,
        ratio: MixValue,
        knee: MixValue,
        attack: MixValue,
        release: MixValue,
        makeup: MixValue
    ) {
        self.threshold = threshold
        self.ratio = ratio
        self.knee = knee
        self.attack = attack
        self.release = release
        self.makeup = makeup
    }

    // MARK: - Public
    // MARK: - Private
}

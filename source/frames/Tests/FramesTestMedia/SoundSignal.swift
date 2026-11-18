//
//  SoundSignal.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/18/26.
//

import Foundation

// What a sound writer writes at full scale 1: a sine tone of a frequency, or white noise, uniform in [-1, 1), the same
// for the same seed and different for another, so two seeds give two uncorrelated sounds.
package enum SoundSignal: Sendable {
    case tone(frequency: Double)
    case noise(seed: UInt64)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The signal of `channel` at frame `index` of a sound at `sampleRate` frames a second.
    func value(
        channel: Int,
        at index: Int,
        sampleRate: Int
    ) -> Double {
        switch self {
        case let .tone(frequency):
            return sin(2 * Double.pi * frequency * Double(index) / Double(sampleRate))

        case let .noise(seed):
            let bits = mixed(seed &+ UInt64(channel) &* 0x9E37_79B9_7F4A_7C15 &+ UInt64(index) &* 0xBF58_476D_1CE4_E5B9)
            return Double(bits >> 11) / Double(1 << 53) * 2 - 1
        }
    }

    // MARK: - Private
    // The SplitMix64 finaliser: every input bit reaches every output bit, so neighbouring inputs give unrelated outputs.
    private func mixed(_ value: UInt64) -> UInt64 {
        var bits = value
        bits = (bits ^ (bits >> 30)) &* 0xBF58_476D_1CE4_E5B9
        bits = (bits ^ (bits >> 27)) &* 0x94D0_49BB_1331_11EB
        return bits ^ (bits >> 31)
    }
}

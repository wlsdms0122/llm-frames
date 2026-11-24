//
//  SplitMix64.swift
//  Frames
//
//  Created by JSilver on 11/24/26.
//

// Steele, Lea and Flood's SplitMix64: a generator of 64-bit values from a 64-bit state, the same sequence for the same
// seed on every machine, which a `random` unit order is drawn from.
struct SplitMix64: RandomNumberGenerator, Sendable {
    // MARK: - Property
    private var state: UInt64

    // MARK: - Initializer
    init(seed: UInt64) {
        self.state = seed
    }

    // MARK: - Public
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB

        return z ^ (z >> 31)
    }

    // MARK: - Private
}

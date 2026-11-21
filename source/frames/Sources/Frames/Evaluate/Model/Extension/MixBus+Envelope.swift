//
//  MixBus+Envelope.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The level the bus's envelope gives sample by sample, as `EnvelopeCursor` reads it. Sample n is at sequence time
// n / `sampleRate`.
extension MixBus {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The level at each output sample of `samples`, 1 where the envelope has no points.
    package func gains(
        atSamples samples: Range<Int>,
        sampleRate: Double
    ) -> [Float] {
        EnvelopeCursor.values(of: envelope, atSamples: samples, sampleRate: sampleRate, empty: 1)
    }

    // MARK: - Private
}

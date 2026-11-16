//
//  SoundBuffer.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Sound as samples: `channels` interleaved samples per frame at `sampleRate` frames a second, in [-1, 1] at full scale.
// A decoder gives a file's own rate and channels, and a mixer gives 48 kHz stereo.
package struct SoundBuffer: Equatable, Sendable {
    // MARK: - Property
    package let sampleRate: Double
    package let channels: Int
    package let samples: [Float]

    package var frameCount: Int {
        samples.count / channels
    }

    // MARK: - Initializer
    package init(
        sampleRate: Double,
        channels: Int,
        samples: [Float]
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.samples = samples
    }

    // MARK: - Public
    // MARK: - Private
}

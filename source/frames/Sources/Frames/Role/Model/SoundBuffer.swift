//
//  SoundBuffer.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// Sound as samples: `channels` interleaved samples per frame at `sampleRate` frames a second, in [-1, 1] at full scale.
// A decoder gives a file's own rate and channels, and a mixer gives 48 kHz stereo. `layout` names the speaker each
// channel feeds, and when none is given it is the channel count's own.
package struct SoundBuffer: Equatable, Sendable {
    // MARK: - Property
    package let sampleRate: Double
    package let channels: Int
    package let samples: [Float]
    package let layout: ChannelLayout

    package var frameCount: Int {
        samples.count / channels
    }

    // MARK: - Initializer
    package init(
        sampleRate: Double,
        channels: Int,
        samples: [Float],
        layout: ChannelLayout? = nil
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.samples = samples
        self.layout = layout ?? ChannelLayout(channels: channels)
    }

    // MARK: - Public
    // MARK: - Private
}

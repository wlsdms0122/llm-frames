//
//  SoundTarget.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// A sound file an encoder writes: an MPEG-4 audio file of AAC at its quality's `soundBitRate` per channel, with the
// sound's channels up to 2, more downmixed to stereo, and its sample rate up to 48 kHz, a higher one converted to it.
// `layout` and `sampleRate` are those of the sound it is given, so the encoder's check refuses one it cannot downmix or
// write before an existing file is removed.
package struct SoundTarget: Equatable, Sendable {
    // MARK: - Property
    package let path: String
    package let quality: EncodeQuality
    package let layout: ChannelLayout
    package let sampleRate: Double

    // MARK: - Initializer
    package init(
        path: String,
        quality: EncodeQuality,
        layout: ChannelLayout,
        sampleRate: Double
    ) {
        self.path = path
        self.quality = quality
        self.layout = layout
        self.sampleRate = sampleRate
    }

    // MARK: - Public
    // MARK: - Private
}

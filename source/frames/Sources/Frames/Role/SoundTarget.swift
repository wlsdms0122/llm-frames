//
//  SoundTarget.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// A sound file an encoder writes: an MPEG-4 audio file of AAC at its quality's `soundBitRate` per channel, with the
// sound's channels up to 2, more downmixed to stereo, and its sample rate up to 48 kHz, a higher one converted to it.
package struct SoundTarget: Equatable, Sendable {
    // MARK: - Property
    package let path: String
    package let quality: EncodeQuality

    // MARK: - Initializer
    package init(
        path: String,
        quality: EncodeQuality
    ) {
        self.path = path
        self.quality = quality
    }

    // MARK: - Public
    // MARK: - Private
}

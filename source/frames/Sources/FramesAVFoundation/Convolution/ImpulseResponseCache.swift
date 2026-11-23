//
//  ImpulseResponseCache.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/23/26.
//

import os
import Frames

// The impulse responses read so far, by pinned file, kept for the mixer's lifetime, so a plan reads each once: when it
// is checked, and not again for each segment, bus or repeat of a loop. Each is read as the mixer reads a segment's
// sound, through the decoder, mapped onto stereo and resampled to the plan's sample rate, with no gain of its own: a
// file of one channel gives both channels its samples as they are.
final class ImpulseResponseCache: Sendable {
    // MARK: - Property
    private let decoder: any MediaDecoder
    private let sampleRate: Double
    private let responses = OSAllocatedUnfairLock<[String: ImpulseResponse]>(initialState: [:])

    // MARK: - Initializer
    init(
        decoder: any MediaDecoder,
        sampleRate: Double
    ) {
        self.decoder = decoder
        self.sampleRate = sampleRate
    }

    // MARK: - Public
    // `place` is the op's place in the plan, which names a failure.
    func impulseResponse(
        of file: PinnedFile,
        place: String
    ) throws -> ImpulseResponse {
        let key = file.sha256 + file.path
        if let response = responses.withLock({ $0[key] }) {
            return response
        }

        let sound: SoundBuffer
        do {
            sound = try decoder.sound(of: MediaFile(path: file.path), from: 0, to: MixConvolution.longestDuration)
        } catch {
            throw MixerError.unreadable(place: place, reason: "\(error)")
        }
        guard let downmixer = StereoDownmixer(layout: sound.layout) else {
            throw MixerError(undownmixable: sound.layout, place: place, file: file.path)
        }
        guard sound.frameCount > 0 else { throw MixerError.emptyImpulseResponse(place: place, file: file.path) }
        let buffer = try Resampler().resampled(
            try downmixer.stereo(from: sound, path: file.path),
            to: sampleRate,
            path: file.path
        )
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0, let channels = buffer.floatChannelData else {
            throw MixerError.emptyImpulseResponse(place: place, file: file.path)
        }

        let taps = (0..<2).map { channel in
            UnsafeBufferPointer(start: channels[channel], count: frameCount).map(Double.init)
        }
        let response = try ImpulseResponse(taps: taps, path: file.path)
        responses.withLock { $0[key] = response }

        return response
    }

    // MARK: - Private
}

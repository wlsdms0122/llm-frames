//
//  AACSoundConverter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/17/26.
//

import AVFoundation
import Foundation
import Frames

// Fits sound to what a compressed file stores in AAC: one or two channels at up to 48 kHz. More channels are downmixed
// to stereo by ITU-R BS.775, as the mixer downmixes them, and a higher rate is converted to 48 kHz. Sound that fits
// already is kept as it is.
struct AACSoundConverter: Sendable {
    // MARK: - Property
    private static let maximumSampleRate: Double = 48_000
    private static let maximumChannels = 2

    // MARK: - Initializer
    // MARK: - Public
    func fitted(
        _ sound: SoundBuffer,
        path: String
    ) throws -> SoundBuffer {
        guard sound.channels > Self.maximumChannels || sound.sampleRate > Self.maximumSampleRate else { return sound }

        do {
            var buffer = try planar(sound, path: path)
            buffer = try Resampler().resampled(
                buffer,
                to: min(sound.sampleRate, Self.maximumSampleRate),
                path: path
            )

            return interleaved(buffer)
        } catch let MixerError.unrenderable(_, reason) {
            throw EncoderError.unwritable(file: path, reason: "its sound cannot be converted: \(reason)")
        }
    }

    // MARK: - Private
    // The sound as one float channel after another, downmixed to stereo when it has more than two.
    private func planar(
        _ sound: SoundBuffer,
        path: String
    ) throws -> AVAudioPCMBuffer {
        if sound.channels > Self.maximumChannels {
            guard let downmixer = StereoDownmixer(layout: sound.layout) else {
                throw EncoderError.undownmixable(file: path)
            }

            return try downmixer.stereo(from: sound, path: path)
        }

        let frameCount = sound.frameCount
        guard
            let format = AVAudioFormat(
                standardFormatWithSampleRate: sound.sampleRate,
                channels: AVAudioChannelCount(sound.channels)
            ),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(frameCount, 1))),
            let channels = buffer.floatChannelData
        else {
            throw EncoderError.unwritable(file: path, reason: "no sound buffer at \(sound.sampleRate) Hz")
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        for channel in 0..<sound.channels {
            for frame in 0..<frameCount {
                channels[channel][frame] = sound.samples[frame * sound.channels + channel]
            }
        }

        return buffer
    }

    private func interleaved(_ buffer: AVAudioPCMBuffer) -> SoundBuffer {
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        var samples = [Float](repeating: 0, count: frameCount * channelCount)
        if let channels = buffer.floatChannelData {
            for channel in 0..<channelCount {
                for frame in 0..<frameCount {
                    samples[frame * channelCount + channel] = channels[channel][frame]
                }
            }
        }

        return SoundBuffer(sampleRate: buffer.format.sampleRate, channels: channelCount, samples: samples)
    }
}

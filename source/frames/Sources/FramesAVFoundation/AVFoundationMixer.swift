//
//  AVFoundationMixer.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import AVFoundation
import Frames

// The `avfoundation` mixer: reads each segment's media time through the decoder, maps its channels onto stereo,
// resamples it to 48 kHz, stretches it in time with the pitch kept when its speed is not 1, multiplies it by its
// envelope and adds it into the output from its start sample. The sum is not clipped.
package final class AVFoundationMixer: Sendable {
    // MARK: - Property
    private static let sampleRate: Double = 48_000

    private let decoder: any MediaDecoder

    // MARK: - Initializer
    package init(decoder: any MediaDecoder) {
        self.decoder = decoder
    }

    // MARK: - Public
    // MARK: - Private
    // The segment's media time [from, to) as the decoder reads it, its failures named by the segment's place.
    private func sound(
        of segment: MixSegment,
        index: Int,
        from start: Double,
        to end: Double
    ) throws -> (path: String, sound: SoundBuffer) {
        guard case let .file(file) = segment.media.source else {
            throw MixerError.noSound(segment: index, file: MediaFile(media: segment.media).path)
        }

        do {
            return (file.path, try decoder.sound(of: file.path, from: start, to: end))
        } catch DecoderError.noSound {
            throw MixerError.noSound(segment: index, file: file.path)
        } catch {
            throw MixerError.unreadable(segment: index, reason: "\(error)")
        }
    }
}

extension AVFoundationMixer: Mixer {
    // MARK: - Lifecycle
    package func check(_ plan: MixPlan) throws {
        for (index, segment) in plan.segments.enumerated() {
            let (path, sound) = try sound(of: segment, index: index, from: segment.mediaStart, to: segment.mediaStart)
            guard StereoDownmixer(layout: sound.layout) != nil else {
                throw MixerError.unmixableChannels(segment: index, file: path)
            }
            guard segment.speed == 1 || TimeStretcher.speeds.contains(segment.speed) else {
                throw MixerError.unstretchable(segment: index, file: path, speed: segment.speed)
            }
        }
    }

    package func mix(
        _ plan: MixPlan,
        duration: Double
    ) throws -> SoundBuffer {
        let frameCount = Int((duration * Self.sampleRate).rounded())
        var samples = [Float](repeating: 0, count: frameCount * 2)

        for (index, segment) in plan.segments.enumerated() {
            let first = Int((segment.start * Self.sampleRate).rounded())
            let last = min(Int((segment.end * Self.sampleRate).rounded()), frameCount)
            guard first < last else { continue }

            let (path, sound) = try sound(
                of: segment,
                index: index,
                from: segment.mediaStart,
                to: segment.mediaStart + (segment.end - segment.start) * segment.speed
            )
            guard let downmixer = StereoDownmixer(layout: sound.layout) else {
                throw MixerError.unmixableChannels(segment: index, file: path)
            }
            var buffer = try downmixer.stereo(from: sound, path: path)
            buffer = try Resampler().resampled(buffer, to: Self.sampleRate, path: path)
            if segment.speed != 1 {
                guard TimeStretcher.speeds.contains(segment.speed) else {
                    throw MixerError.unstretchable(segment: index, file: path, speed: segment.speed)
                }
                buffer = try TimeStretcher().stretched(buffer, speed: segment.speed, path: path)
            }

            let gains = segment.gains(atSamples: first..<last, sampleRate: Self.sampleRate)
            let heard = min(last - first, Int(buffer.frameLength))
            guard heard > 0, let channels = buffer.floatChannelData else { continue }
            for offset in max(-first, 0)..<heard {
                let gain = gains[offset]
                samples[(first + offset) * 2] += channels[0][offset] * gain
                samples[(first + offset) * 2 + 1] += channels[1][offset] * gain
            }
        }

        return SoundBuffer(sampleRate: Self.sampleRate, channels: 2, samples: samples)
    }
}

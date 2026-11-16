//
//  Resampler.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import AVFoundation

// Converts sound to another sample rate with AVAudioConverter at its best quality, the whole buffer at once so the
// converter's filter delay is flushed at the end.
struct Resampler {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func resampled(
        _ buffer: AVAudioPCMBuffer,
        to sampleRate: Double,
        path: String
    ) throws -> AVAudioPCMBuffer {
        guard buffer.format.sampleRate != sampleRate else { return buffer }
        let capacity = (Double(buffer.frameLength) * sampleRate / buffer.format.sampleRate).rounded(.up) + 1
        guard
            let format = AVAudioFormat(
                standardFormatWithSampleRate: sampleRate,
                channels: buffer.format.channelCount
            ),
            let converter = AVAudioConverter(from: buffer.format, to: format),
            let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(capacity))
        else {
            throw MixerError.unrenderable(file: path, reason: "no converter to \(sampleRate) Hz")
        }
        converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue
        converter.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Mastering

        var given = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            guard !given else {
                inputStatus.pointee = .endOfStream
                return nil
            }
            given = true
            inputStatus.pointee = .haveData

            return buffer
        }
        guard status != .error else {
            throw MixerError.unrenderable(file: path, reason: error?.localizedDescription ?? "the conversion failed")
        }

        return output
    }

    // MARK: - Private
}

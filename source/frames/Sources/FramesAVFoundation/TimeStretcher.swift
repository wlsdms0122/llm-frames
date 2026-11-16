//
//  TimeStretcher.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import AVFoundation

// Stretches sound in time with its pitch kept: AVAudioUnitTimePitch in an AVAudioEngine rendering offline. The unit's
// latency is rendered past the end and dropped from the start, so the stretched sound starts where the source does.
struct TimeStretcher {
    // MARK: - Property
    // The rates AVAudioUnitTimePitch plays at.
    static let speeds: ClosedRange<Double> = 1.0 / 32...32

    private static let maximumFrameCount: AVAudioFrameCount = 4_096

    // MARK: - Initializer
    // MARK: - Public
    // The source played at `speed`, so it lasts its length divided by `speed`.
    func stretched(
        _ buffer: AVAudioPCMBuffer,
        speed: Double,
        path: String
    ) throws -> AVAudioPCMBuffer {
        let format = buffer.format
        let length = Int((Double(buffer.frameLength) / speed).rounded())
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let timePitch = AVAudioUnitTimePitch()
        timePitch.rate = Float(speed)
        engine.attach(player)
        engine.attach(timePitch)
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)
        guard
            let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(length, 1))),
            let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: Self.maximumFrameCount)
        else {
            throw MixerError.unrenderable(file: path, reason: "no buffer to stretch \(length) frames into")
        }
        do {
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: Self.maximumFrameCount)
            try engine.start()
        } catch {
            throw MixerError.unrenderable(file: path, reason: error.localizedDescription)
        }
        defer { engine.stop() }
        player.scheduleBuffer(buffer)
        player.play()

        let latency = Int((timePitch.auAudioUnit.latency * format.sampleRate).rounded())
        var rendered = 0
        while rendered < latency + length {
            let frames = AVAudioFrameCount(min(Int(Self.maximumFrameCount), latency + length - rendered))
            let status: AVAudioEngineManualRenderingStatus
            do {
                status = try engine.renderOffline(frames, to: chunk)
            } catch {
                throw MixerError.unrenderable(file: path, reason: error.localizedDescription)
            }
            guard status == .success else {
                throw MixerError.unrenderable(file: path, reason: "the time stretch stopped at frame \(rendered)")
            }
            append(chunk, skipping: max(latency - rendered, 0), to: output)
            rendered += Int(chunk.frameLength)
        }

        return output
    }

    // MARK: - Private
    private func append(
        _ chunk: AVAudioPCMBuffer,
        skipping skipped: Int,
        to output: AVAudioPCMBuffer
    ) {
        let kept = min(Int(chunk.frameLength) - skipped, Int(output.frameCapacity - output.frameLength))
        guard kept > 0, let source = chunk.floatChannelData, let destination = output.floatChannelData else { return }

        let start = Int(output.frameLength)
        for channel in 0..<Int(chunk.format.channelCount) {
            (destination[channel] + start).update(from: source[channel] + skipped, count: kept)
        }
        output.frameLength += AVAudioFrameCount(kept)
    }
}

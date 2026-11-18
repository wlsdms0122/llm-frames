//
//  StereoDownmixer.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import AVFoundation
import Frames

// Maps a sound's channels onto stereo. One channel plays at the same level on both, and any other layout is mixed by
// its labels, by ITU-R BS.775: left and right on their own sides, a centre at 0.7071 into both, a surround at 0.7071
// into its side, a centre surround at 0.5 into both, and the low frequency effects dropped.
struct StereoDownmixer {
    // MARK: - Property
    private static let minusThreeDecibels: Float = 0.7071

    private let gains: [StereoGain]

    // MARK: - Initializer
    // Nil for a layout with a channel BS.775 names no speaker for.
    init?(layout: ChannelLayout) {
        guard !layout.isMono else {
            gains = [StereoGain(left: 1, right: 1)]
            return
        }

        let gains = layout.labels.map(Self.gains(of:))
        guard !gains.contains(where: { $0 == nil }) else { return nil }

        self.gains = gains.compactMap { $0 }
    }

    // MARK: - Public
    func stereo(
        from sound: SoundBuffer,
        path: String
    ) throws -> AVAudioPCMBuffer {
        let frameCount = sound.frameCount
        guard
            let format = AVAudioFormat(standardFormatWithSampleRate: sound.sampleRate, channels: 2),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(frameCount, 1))),
            let channels = buffer.floatChannelData
        else {
            throw MixerError.unrenderable(file: path, reason: "no stereo buffer at \(sound.sampleRate) Hz")
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        let left = channels[0]
        let right = channels[1]
        for frame in 0..<frameCount {
            var leftSum: Float = 0
            var rightSum: Float = 0
            for (channel, gain) in gains.enumerated() {
                let sample = sound.samples[frame * sound.channels + channel]
                leftSum += gain.left * sample
                rightSum += gain.right * sample
            }
            left[frame] = leftSum
            right[frame] = rightSum
        }

        return buffer
    }

    // MARK: - Private
    private static func gains(of label: ChannelLabel) -> StereoGain? {
        switch label {
        case .left:
            StereoGain(left: 1, right: 0)

        case .right:
            StereoGain(left: 0, right: 1)

        case .mono, .center:
            StereoGain(left: minusThreeDecibels, right: minusThreeDecibels)

        case .lowFrequencyEffects:
            StereoGain(left: 0, right: 0)

        case .leftSurround, .leftRearSurround:
            StereoGain(left: minusThreeDecibels, right: 0)

        case .rightSurround, .rightRearSurround:
            StereoGain(left: 0, right: minusThreeDecibels)

        case .centerSurround:
            StereoGain(left: 0.5, right: 0.5)

        case .discrete:
            nil
        }
    }
}

//
//  AudioFilterChain.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/19/26.
//

import AVFoundation
import Frames

// A chain of audio filter entries over a stereo sound at the mix plan's sample rate: a segment's `audioFilter`, after
// the downmix, the resampling and the time stretch and before the gain and the pan, a bus's chain, over the bus's sum
// and before its level, or the plan's chain, over the whole mix. It is made at rest, so each segment and each bus, and
// so each repeat of a loop, starts every op at rest. Each entry runs over the whole sound in turn, reading the buffer's
// 32-bit samples, and its result is rounded to them before the next entry reads it.
final class AudioFilterChain {
    // MARK: - Property
    private let entries: [FilterEntryProcessor]

    // MARK: - Initializer
    init(
        filter: [MixFilterEntry],
        sampleRate: Double
    ) {
        self.entries = filter.map { FilterEntryProcessor(entry: $0, sampleRate: sampleRate) }
    }

    // MARK: - Public
    // `first` is the sequence sample the buffer's first frame plays at, and the sound ends after `frames` frames.
    func process(
        _ buffer: AVAudioPCMBuffer,
        frames: Int,
        first: Int
    ) {
        guard !entries.isEmpty, let channels = buffer.floatChannelData else { return }

        process([channels[0], channels[1]], frames: frames, first: first)
    }

    // Runs the chain over `frames` samples of each of the two `channels` in place, frame 0 at sequence sample `first`.
    func process(
        _ channels: [UnsafeMutablePointer<Float>],
        frames: Int,
        first: Int
    ) {
        for entry in entries {
            entry.process(channels, frames: frames, first: first)
        }
    }

    // MARK: - Private
}

//
//  SegmentFilter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/19/26.
//

import AVFoundation
import Frames

// A segment's audio filter over its stereo sound at 48 kHz, after the downmix, the resampling and the time stretch
// and before the gain and the pan. It is made at rest, so each segment, and each repeat of a loop, which is a segment
// of its own, starts every op at rest. Entries none of whose ops reads ahead run together sample by sample, and an
// entry with a limiter runs over the whole sound, reading silence past its end.
final class SegmentFilter {
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

    // Runs the filter over `frames` samples of each of the two `channels` in place, frame 0 at sequence sample `first`.
    func process(
        _ channels: [UnsafeMutablePointer<Float>],
        frames: Int,
        first: Int
    ) {
        var start = 0
        while start < entries.count {
            guard !entries[start].readsAhead else {
                entries[start].process(channels, frames: frames, first: first)
                start += 1
                continue
            }

            let run = entries[start...].prefix { !$0.readsAhead }
            for frame in 0..<frames {
                let input = StereoSample(left: Double(channels[0][frame]), right: Double(channels[1][frame]))
                let output = run.reduce(input) { output, entry in entry.process(output, atSample: first + frame) }
                channels[0][frame] = Float(output.left)
                channels[1][frame] = Float(output.right)
            }
            start += run.count
        }
    }

    // MARK: - Private
}

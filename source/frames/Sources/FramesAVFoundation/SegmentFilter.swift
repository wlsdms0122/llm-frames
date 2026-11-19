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
// of its own, starts every op at rest.
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
    // `first` is the sequence sample the buffer's first frame plays at.
    func process(
        _ buffer: AVAudioPCMBuffer,
        frames: Int,
        first: Int
    ) {
        guard !entries.isEmpty, let channels = buffer.floatChannelData else { return }

        for frame in 0..<frames {
            let input = StereoSample(left: Double(channels[0][frame]), right: Double(channels[1][frame]))
            let output = process(input, atSample: first + frame)
            channels[0][frame] = Float(output.left)
            channels[1][frame] = Float(output.right)
        }
    }

    func process(
        _ input: StereoSample,
        atSample sample: Int
    ) -> StereoSample {
        entries.reduce(input) { output, entry in entry.process(output, atSample: sample) }
    }

    // MARK: - Private
}

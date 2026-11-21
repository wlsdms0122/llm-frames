//
//  FilterEntryProcessor.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/19/26.
//

import Frames

// One entry of a filter: its ops in order on the entry's input, and that input mixed with their result by the entry's
// `mix`, clamped to 0 to 1. The ops run at every `mix`, so their state is current when `mix` moves up from 0.
final class FilterEntryProcessor {
    // MARK: - Property
    private let sampleRate: Double
    private let stages: [FilterStage]
    private let isWholeWet: Bool
    private var mix: EnvelopeCursor

    // MARK: - Initializer
    init(
        entry: MixFilterEntry,
        sampleRate: Double
    ) {
        self.sampleRate = sampleRate
        self.stages = FilterStage.stages(of: entry.operations, sampleRate: sampleRate)
        self.isWholeWet = if case let .constant(mix) = entry.mix { mix >= 1 } else { false }
        self.mix = EnvelopeCursor(value: entry.mix)
    }

    // MARK: - Public
    // Runs the entry over `frames` samples of each of `channels` in place, frame 0 at sequence sample `first`. The dry
    // input is kept for the mix only where `mix` is not 1 throughout.
    func process(
        _ channels: [UnsafeMutablePointer<Float>],
        frames: Int,
        first: Int
    ) {
        let dry = isWholeWet ? [] : channels.map { Array(UnsafeBufferPointer(start: $0, count: frames)) }
        for stage in stages {
            stage.process(channels, frames: frames, first: first)
        }
        guard !isWholeWet else { return }

        for frame in 0..<frames {
            let mix = min(max(mix.value(at: Double(first + frame) / sampleRate), 0), 1)
            let input = StereoSample(left: Double(dry[0][frame]), right: Double(dry[1][frame]))
            let wet = StereoSample(left: Double(channels[0][frame]), right: Double(channels[1][frame]))
            let output = input.mixed(with: wet, by: mix)
            channels[0][frame] = Float(output.left)
            channels[1][frame] = Float(output.right)
        }
    }

    // MARK: - Private
}

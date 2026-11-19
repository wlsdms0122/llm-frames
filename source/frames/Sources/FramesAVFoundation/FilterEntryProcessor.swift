//
//  FilterEntryProcessor.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/19/26.
//

import Frames

// One entry of a segment's filter: its ops in order on the entry's input, and that input mixed with their result by
// the entry's `mix`, clamped to 0 to 1. The ops run at every `mix`, so their state is current when `mix` moves up
// from 0.
final class FilterEntryProcessor: AudioOperationProcessor {
    // MARK: - Property
    private let sampleRate: Double
    private let operations: [any AudioOperationProcessor]
    private var mix: EnvelopeCursor

    // MARK: - Initializer
    init(
        entry: MixFilterEntry,
        sampleRate: Double
    ) {
        self.sampleRate = sampleRate
        self.operations = entry.operations.map { operation in
            switch operation {
            case let .eq(bands):
                EqualizerProcessor(bands: bands, sampleRate: sampleRate)

            case let .compressor(compressor):
                CompressorProcessor(compressor: compressor, sampleRate: sampleRate)

            case let .gate(gate):
                GateProcessor(gate: gate, sampleRate: sampleRate)
            }
        }
        self.mix = EnvelopeCursor(value: entry.mix)
    }

    // MARK: - Lifecycle
    func process(
        _ input: StereoSample,
        atSample sample: Int
    ) -> StereoSample {
        let wet = operations.reduce(input) { output, operation in operation.process(output, atSample: sample) }
        let mix = min(max(mix.value(at: Double(sample) / sampleRate), 0), 1)

        return input.mixed(with: wet, by: mix)
    }

    // MARK: - Public
    // MARK: - Private
}

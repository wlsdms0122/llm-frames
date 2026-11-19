//
//  FilterEntryProcessorTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import Frames
@testable import FramesAVFoundation
import Testing

@Suite("FilterEntryProcessor Tests")
struct FilterEntryProcessorTests {
    // MARK: - Property
    private static let sampleRate = 48_000.0

    // A high pass at 2 kHz with a hard compressor after it.
    private let operations: [MixFilterOperation] = [
        .eq(bands: [MixBand(type: .highPass, frequency: .constant(2000), gain: nil, q: .constant(0.7071))]),
        .compressor(MixCompressor(
            threshold: .constant(-30),
            ratio: .constant(8),
            knee: .constant(0),
            attack: .constant(0.001),
            release: .constant(0.05),
            makeup: .constant(0)
        ))
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("an entry at `mix` 0 is its dry input, sample for sample")
    func passesDryAtZero() {
        // Given
        let sut = FilterEntryProcessor(entry: MixFilterEntry(operations: operations, mix: .constant(0)), sampleRate: Self.sampleRate)
        let inputs = signal(count: 9600)

        // When
        let outputs = inputs.enumerated().map { sut.process($1, atSample: $0) }

        // Then
        #expect(outputs == inputs)
    }

    @Test("an `eq` with a `highPass` band fades in by `mix`, dry × (1 - mix) + wet × mix on each channel")
    func fadesInByMix() {
        // Given
        let mix = MixValue.envelope([EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: 0.2, value: 1)])
        let sut = FilterEntryProcessor(entry: MixFilterEntry(operations: operations, mix: mix), sampleRate: Self.sampleRate)
        let wet = FilterEntryProcessor(entry: MixFilterEntry(operations: operations, mix: .constant(1)), sampleRate: Self.sampleRate)
        let inputs = signal(count: 14_400)

        // When
        let outputs = inputs.enumerated().map { sut.process($1, atSample: $0) }

        // Then
        let wets = inputs.enumerated().map { wet.process($1, atSample: $0) }
        for sample in [0, 2400, 4800, 7200, 9600, 12_000] {
            let fraction = min(Double(sample) / 9600, 1)
            let expected = inputs[sample].mixed(with: wets[sample], by: fraction)
            #expect(abs(outputs[sample].left - expected.left) < 1e-12 && abs(outputs[sample].right - expected.right) < 1e-12)
        }
        #expect(outputs[12_000] == wets[12_000])
    }

    @Test("a segment's entries run in order, each on the sound the one before it gives")
    func runsEntriesInOrder() {
        // Given
        let entries = operations.map { MixFilterEntry(operations: [$0], mix: .constant(1)) }
        let sut = SegmentFilter(filter: entries, sampleRate: Self.sampleRate)
        let chained = FilterEntryProcessor(entry: MixFilterEntry(operations: operations, mix: .constant(1)), sampleRate: Self.sampleRate)
        let inputs = signal(count: 4800)

        // When
        let outputs = inputs.enumerated().map { sut.process($1, atSample: $0) }

        // Then
        #expect(outputs == inputs.enumerated().map { chained.process($1, atSample: $0) })
    }

    // MARK: - Private
    // A 440 Hz and a 5 kHz tone, louder on the left.
    private func signal(count: Int) -> [StereoSample] {
        (0..<count).map { sample in
            let time = Double(sample) / Self.sampleRate
            let value = 0.4 * sin(2 * .pi * 440 * time) + 0.2 * sin(2 * .pi * 5000 * time)
            return StereoSample(left: value, right: value / 2)
        }
    }
}

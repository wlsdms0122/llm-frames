//
//  FilterEntryProcessorTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import Frames
@testable import FramesAVFoundation
import FramesTestMedia
import Testing

@Suite("FilterEntryProcessor Tests")
struct FilterEntryProcessorTests {
    // MARK: - Property
    private static let sampleRate = 48_000.0

    // A high pass at 2 kHz.
    private static let highPass = [MixBand(type: .highPass, frequency: .constant(2000), gain: nil, q: .constant(0.7071))]

    // A hard compressor.
    private static let compressor = MixCompressor(
        threshold: .constant(-30),
        ratio: .constant(8),
        knee: .constant(0),
        attack: .constant(0.001),
        release: .constant(0.05),
        makeup: .constant(0)
    )

    // The high pass with the compressor after it.
    private let operations: [MixFilterOperation] = [.eq(bands: Self.highPass), .compressor(Self.compressor)]

    // No entry here convolves, so it reads no impulse response.
    private let impulseResponses = ImpulseResponseCache(decoder: AVFoundationDecoder(), sampleRate: Self.sampleRate)

    // A limiter at its defaults.
    private static let limiter = MixLimiter(gain: .constant(0), ceiling: .constant(-1), lookahead: 0.005, release: .constant(0.1))

    // MARK: - Initializer
    // MARK: - Test
    @Test("an entry at `mix` 0 is its dry input, sample for sample")
    func passesDryAtZero() throws {
        // Given
        let sut = try entryProcessor(MixFilterEntry(operations: operations, mix: .constant(0)))
        let inputs = rounded(signal(count: 9600))

        // When
        let outputs = filtered(inputs, by: sut)

        // Then
        #expect(outputs == inputs)
    }

    @Test("an `eq` with a `highPass` band fades in by `mix`, dry × (1 - mix) + wet × mix on each channel")
    func fadesInByMix() throws {
        // Given
        let mix = MixValue.envelope([EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: 0.2, value: 1)])
        let sut = try entryProcessor(MixFilterEntry(operations: operations, mix: mix))
        let wet = try entryProcessor(MixFilterEntry(operations: operations, mix: .constant(1)))
        let inputs = rounded(signal(count: 14_400))

        // When
        let outputs = filtered(inputs, by: sut)

        // Then
        let wets = filtered(inputs, by: wet)
        for sample in [0, 2400, 4800, 7200, 9600, 12_000] {
            let fraction = min(Double(sample) / 9600, 1)
            let expected = rounded([inputs[sample].mixed(with: wets[sample], by: fraction)])[0]
            #expect(abs(outputs[sample].left - expected.left) < 1e-12 && abs(outputs[sample].right - expected.right) < 1e-12)
        }
        #expect(outputs[12_000] == wets[12_000])
    }

    @Test("a segment's entries run in order, each on the sound the one before it gives, rounded to the buffer's samples")
    func runsEntriesInOrder() throws {
        // Given
        let entries = operations.map { MixFilterEntry(operations: [$0], mix: .constant(1)) }
        let sut = try chain(entries)
        let processors: [any AudioOperationProcessor] = [
            EqualizerProcessor(bands: Self.highPass, sampleRate: Self.sampleRate),
            CompressorProcessor(compressor: Self.compressor, sampleRate: Self.sampleRate)
        ]
        let inputs = rounded(signal(count: 4800))

        // When
        let outputs = filtered(inputs, by: sut)

        // Then
        let expected = processors.reduce(inputs) { sound, processor in
            rounded(sound.enumerated().map { processor.process($1, atSample: $0) })
        }
        #expect(outputs == expected)
    }

    @Test("an entry with a limiter at `mix` 0.5 is half its dry input and half its limited sound")
    func mixesLimitedEntry() throws {
        // Given
        let limited = operations + [.limiter(Self.limiter)]
        let sut = try chain([MixFilterEntry(operations: limited, mix: .constant(0.5))])
        let wet = try chain([MixFilterEntry(operations: limited, mix: .constant(1))])
        let inputs = signal(count: 9600).map { $0.scaled(by: 4) }

        // When
        let outputs = filtered(inputs, by: sut)

        // Then
        let wets = filtered(inputs, by: wet)
        let dry = rounded(inputs)
        let deviation = (0..<9600).map { sample in
            let expected = dry[sample].mixed(with: wets[sample], by: 0.5)
            return max(abs(outputs[sample].left - expected.left), abs(outputs[sample].right - expected.right))
        }.max()!
        #expect(deviation < 1e-6, "\(deviation)")
        #expect(wets.allSatisfy { max(abs($0.left), abs($0.right)) <= pow(10, -1.0 / 20) * (1 + 1e-6) })
    }

    @Test("an entry with a limiter between two others takes the sound the one before it gives and gives the next its own")
    func runsLimiterInChain() throws {
        // Given
        let entries = [
            MixFilterEntry(operations: [operations[0]], mix: .constant(1)),
            MixFilterEntry(operations: [.limiter(Self.limiter)], mix: .constant(1)),
            MixFilterEntry(operations: [operations[1]], mix: .constant(1))
        ]
        let sut = try chain(entries)
        let inputs = signal(count: 9600).map { $0.scaled(by: 4) }

        // When
        let outputs = filtered(inputs, by: sut)

        // Then
        let separate = try entries.reduce(inputs) { sound, entry in
            filtered(sound, by: try chain([entry]))
        }
        #expect(outputs == separate)
    }

    @Test("the ops of one entry that take one sample at a time compute together, rounded to the buffer's samples once")
    func roundsSampleOpsOnce() throws {
        // Given
        let sut = try chain([MixFilterEntry(operations: operations, mix: .constant(1))])
        let processors: [any AudioOperationProcessor] = [
            EqualizerProcessor(bands: Self.highPass, sampleRate: Self.sampleRate),
            CompressorProcessor(compressor: Self.compressor, sampleRate: Self.sampleRate)
        ]
        let inputs = rounded(signal(count: 4800))

        // When
        let outputs = filtered(inputs, by: sut)

        // Then
        let expected = rounded(inputs.enumerated().map { sample, input in
            processors.reduce(input) { sound, processor in processor.process(sound, atSample: sample) }
        })
        #expect(outputs == expected)
    }

    @Test(
        "a limiter or a convolve in one entry splits it: the ops on each side are rounded to the buffer's samples, as entries of their own",
        arguments: ["limiter", "convolve"]
    )
    func roundsAroundWholeSoundOps(op: String) throws {
        // Given
        let directory = try TemporaryDirectory()
        let response = directory.file("room.wav")
        try WaveFileWriter(channels: [[0.6, 0.3, -0.2, 0.1], [0.5, -0.25, 0.125, 0.0625]]).write(to: response)
        let middle: MixFilterOperation = op == "limiter"
            ? .limiter(Self.limiter)
            : .convolve(MixConvolution(file: PinnedFile(path: response, sha256: ""), gain: .constant(0)))
        let split = [operations[0], middle, operations[1]]
        let sut = try chain([MixFilterEntry(operations: split, mix: .constant(1))])
        let separate = try chain(split.map { MixFilterEntry(operations: [$0], mix: .constant(1)) })
        let inputs = rounded(signal(count: 9600).map { $0.scaled(by: 4) })

        // When
        let outputs = filtered(inputs, by: sut)

        // Then
        #expect(outputs == filtered(inputs, by: separate))
    }

    // MARK: - Private
    private func entryProcessor(_ entry: MixFilterEntry) throws -> FilterEntryProcessor {
        try FilterEntryProcessor(entry: entry, place: "", sampleRate: Self.sampleRate, impulseResponses: impulseResponses)
    }

    private func chain(_ filter: [MixFilterEntry]) throws -> AudioFilterChain {
        try AudioFilterChain(filter: filter, place: "", sampleRate: Self.sampleRate, impulseResponses: impulseResponses)
    }

    // `inputs` through `filter` as one sound from sequence sample 0.
    private func filtered(
        _ inputs: [StereoSample],
        by filter: AudioFilterChain
    ) -> [StereoSample] {
        filtered(inputs) { channels, frames in filter.process(channels, frames: frames, first: 0) }
    }

    // `inputs` through `entry` as one sound from sequence sample 0.
    private func filtered(
        _ inputs: [StereoSample],
        by entry: FilterEntryProcessor
    ) -> [StereoSample] {
        filtered(inputs) { channels, frames in entry.process(channels, frames: frames, first: 0) }
    }

    // `inputs` as a buffer of 32-bit samples, processed in place by `process`.
    private func filtered(
        _ inputs: [StereoSample],
        process: ([UnsafeMutablePointer<Float>], Int) -> Void
    ) -> [StereoSample] {
        var left = inputs.map { Float($0.left) }
        var right = inputs.map { Float($0.right) }
        left.withUnsafeMutableBufferPointer { left in
            right.withUnsafeMutableBufferPointer { right in
                process([left.baseAddress!, right.baseAddress!], inputs.count)
            }
        }

        return zip(left, right).map { StereoSample(left: Double($0), right: Double($1)) }
    }

    // `samples` rounded to 32-bit samples, as a buffer holds them.
    private func rounded(_ samples: [StereoSample]) -> [StereoSample] {
        samples.map { StereoSample(left: Double(Float($0.left)), right: Double(Float($0.right))) }
    }

    // A 440 Hz and a 5 kHz tone, louder on the left.
    private func signal(count: Int) -> [StereoSample] {
        (0..<count).map { sample in
            let time = Double(sample) / Self.sampleRate
            let value = 0.4 * sin(2 * .pi * 440 * time) + 0.2 * sin(2 * .pi * 5000 * time)
            return StereoSample(left: value, right: value / 2)
        }
    }
}

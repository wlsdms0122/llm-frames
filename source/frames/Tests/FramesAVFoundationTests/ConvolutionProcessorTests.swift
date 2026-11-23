//
//  ConvolutionProcessorTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/23/26.
//

import Foundation
@testable import Frames
@testable import FramesAVFoundation
import FramesTestMedia
import Testing

@Suite("ConvolutionProcessor Tests")
struct ConvolutionProcessorTests {
    // MARK: - Property
    private static let sampleRate = 48_000.0

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a short h gives the direct sum sample for sample, within 2 × 2^-23 of Σ|h| × max|x|",
        arguments: [1, 127, 128, 129, 1000, 2049]
    )
    func followsDirectSum(tapCount: Int) throws {
        // Given
        let taps = noises(count: tapCount, seeds: [3, 4], level: 0.5)
        let input = noises(count: 4800, seeds: [5, 6], level: 0.8)
        let sut = try processor(taps: taps)

        // When
        let output = processed(input, by: sut, blockSizes: [4800])

        // Then
        for channel in 0..<2 {
            let reference = directSum(of: input[channel], by: taps[channel], at: 0..<4800)
            let largest = deviation(of: output[channel], from: reference, at: 0..<4800)
            #expect(largest <= bound(taps: taps[channel], input: input[channel]), "channel \(channel): \(largest)")
        }
    }

    @Test("an h of 3 seconds, through every stage, gives the direct sum on a sound of a short burst and silence after it")
    func followsDirectSumOverLongResponse() throws {
        // Given
        let tapCount = 144_000
        let frames = 168_000
        let taps = noises(count: tapCount, seeds: [7, 8], level: 0.1)
        let input = noises(count: 256, seeds: [9, 10], level: 0.8).map { $0 + [Float](repeating: 0, count: frames - 256) }
        let sut = try processor(taps: taps)

        // When
        let output = processed(input, by: sut, blockSizes: [frames])

        // Then
        for channel in 0..<2 {
            let reference = directSum(of: input[channel], by: taps[channel], at: 0..<frames, inputCount: 256)
            let largest = deviation(of: output[channel], from: reference, at: 0..<frames)
            #expect(largest <= bound(taps: taps[channel], input: input[channel]), "channel \(channel): \(largest)")
            #expect(output[channel][frames - 1] != 0)
        }
    }

    @Test("the same sound handed over in blocks of other sizes gives the same samples, within 2 × 2^-23 of its peak")
    func doesNotDependOnBlockSizes() throws {
        // Given
        let frames = 40_000
        let taps = noises(count: 20_000, seeds: [11, 12], level: 0.05)
        let input = noises(count: frames, seeds: [13, 14], level: 0.8)
        let whole = processed(input, by: try processor(taps: taps), blockSizes: [frames])
        let tolerance = (0..<2).map { channel in
            2 * Double(Float.ulpOfOne) * Double(whole[channel].map(abs).max()!)
        }

        for blockSizes in [[1], [7, 100, 3], [127, 128, 129], [4096], [999, 13_001, 5]] {
            // When
            let output = processed(input, by: try processor(taps: taps), blockSizes: blockSizes)

            // Then
            for channel in 0..<2 {
                let largest = deviation(of: output[channel], from: whole[channel].map(Double.init), at: 0..<frames)
                #expect(largest <= tolerance[channel], "blocks \(blockSizes), channel \(channel): \(largest)")
            }
        }
    }

    @Test("a moving `gain` scales each sample by 10^(G / 20), G read at the sample's sequence time")
    func readsGainEnvelopeAtEachSample() throws {
        // Given
        let first = 4800
        let gain = MixValue.envelope([EnvelopePoint(time: 0.1, value: -20), EnvelopePoint(time: 0.2, value: 6)])
        let taps: [[Float]] = [[1, 0.5], [0.25]]
        let input = noises(count: 9600, seeds: [15, 16], level: 0.5)
        let sut = try processor(taps: taps, gain: gain)

        // When
        let output = processed(input, by: sut, blockSizes: [1000, 8600], first: first)

        // Then
        var cursor = EnvelopeCursor(value: gain)
        for frame in 0..<9600 {
            let scale = pow(10, cursor.value(at: Double(first + frame) / Self.sampleRate) / 20)
            for channel in 0..<2 {
                let expected = scale * directSum(of: input[channel], by: taps[channel], at: frame..<frame + 1)[0]
                #expect(abs(Double(output[channel][frame]) - expected) <= 1e-6, "frame \(frame), channel \(channel)")
            }
        }
    }

    // MARK: - Private
    private func processor(
        taps: [[Float]],
        gain: MixValue = .constant(0)
    ) throws -> ConvolutionProcessor {
        let count = taps.map(\.count).max()!
        let padded = taps.map { $0.map(Double.init) + [Double](repeating: 0, count: count - $0.count) }

        return try ConvolutionProcessor(
            convolution: MixConvolution(file: PinnedFile(path: "h.wav", sha256: ""), gain: gain),
            impulseResponse: ImpulseResponse(taps: padded, path: "h.wav"),
            sampleRate: Self.sampleRate
        )
    }

    // `input` through `processor`, handed over in blocks of `blockSizes` in turn, the last repeated to the end.
    private func processed(
        _ input: [[Float]],
        by processor: ConvolutionProcessor,
        blockSizes: [Int],
        first: Int = 0
    ) -> [[Float]] {
        var left = input[0]
        var right = input[1]
        left.withUnsafeMutableBufferPointer { left in
            right.withUnsafeMutableBufferPointer { right in
                var frame = 0
                var block = 0
                while frame < left.count {
                    let count = min(blockSizes[min(block, blockSizes.count - 1)], left.count - frame)
                    processor.process(
                        [left.baseAddress! + frame, right.baseAddress! + frame],
                        frames: count,
                        first: first + frame
                    )
                    frame += count
                    block += 1
                }
            }
        }

        return [left, right]
    }

    // Σ h[k] x[n - k] in double precision for each n of `frames`, x 0 before 0 and from `inputCount` on.
    private func directSum(
        of input: [Float],
        by taps: [Float],
        at frames: Range<Int>,
        inputCount: Int? = nil
    ) -> [Double] {
        let inputCount = inputCount ?? input.count

        return input.withUnsafeBufferPointer { input in
            taps.withUnsafeBufferPointer { taps in
                frames.map { frame in
                    let lowest = max(0, frame - taps.count + 1)
                    let highest = min(frame, inputCount - 1)
                    guard lowest <= highest else { return 0 }

                    var sum = 0.0
                    for index in lowest...highest {
                        sum += Double(taps[frame - index]) * Double(input[index])
                    }
                    return sum
                }
            }
        }
    }

    private func deviation(
        of output: [Float],
        from reference: [Double],
        at frames: Range<Int>
    ) -> Double {
        frames.map { abs(Double(output[$0]) - reference[$0 - frames.lowerBound]) }.max() ?? 0
    }

    // The rounding bound: 2 × 2^-23 of the largest output the sum can reach.
    private func bound(
        taps: [Float],
        input: [Float]
    ) -> Double {
        let largest = input.map { Double(abs($0)) }.max() ?? 0

        return 2 * Double(Float.ulpOfOne) * taps.reduce(0) { $0 + Double(abs($1)) } * largest
    }

    // Two channels of `count` samples of noise in [-`level`, `level`], one seed each.
    private func noises(
        count: Int,
        seeds: [UInt64],
        level: Float
    ) -> [[Float]] {
        seeds.map { seed in
            (0..<count).map { level * Float(SoundSignal.noise(seed: seed).value(channel: 0, at: $0, sampleRate: 48_000)) }
        }
    }
}

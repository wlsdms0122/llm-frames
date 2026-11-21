//
//  PeakDetectorTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
import FramesTestMedia
import Testing

@testable import Frames

@Suite("PeakDetector Tests")
struct PeakDetectorTests {
    // MARK: - Property
    private let sut = PeakDetector()

    // MARK: - Initializer
    // MARK: - Test
    @Test("the phases are the Annex 2 table, h_2 h_1 reversed and h_3 h_0 reversed, with the absolute tap sums of FRAMES-28")
    func holdsAnnexTable() {
        // Given
        let phases = InterpolatingFilter.phases

        // When
        let sums = phases.map { phase in phase.reduce(0) { $0 + abs(Double($1)) } }

        // Then
        #expect(phases.count == 4 && phases.allSatisfy { $0.count == 12 })
        #expect(phases[2] == phases[1].reversed() && phases[3] == phases[0].reversed())
        #expect(phases[0][6] == 0.9721679687500 && phases[1][0] == -0.0291748046875)
        #expect(sums[1] == 2.0228271484375 && sums[2] == 2.0228271484375)
        #expect(sums[0] == 1.4342041015625 && sums[3] == 1.4342041015625)
    }

    @Test("P[n] is the largest |x_c[n]|, |u_c,p[n + 5]| and |u_c,p[n + 6]| over both channels, silence read outside the sound")
    func detectsBySum() {
        // Given
        let left = noise(seed: 3, count: 200)
        let right = noise(seed: 4, count: 200).map { $0 / 2 }

        // When
        let peaks = detected([left, right], stride: 1, from: -20, count: 240)

        // Then
        for index in 0..<240 {
            let sample = index - 20
            let expected = max(reference(left, at: sample), reference(right, at: sample))
            #expect(abs(Double(peaks[index]) - expected) < 1e-6, "\(sample)")
        }
        #expect(peaks[0] == 0 && peaks[239] == 0)
        #expect(peaks[14] > 0 && peaks[225] > 0)
    }

    @Test("interleaved channels read with a stride of 2 give the same peaks as each channel on its own")
    func readsInterleaved() {
        // Given
        let left = noise(seed: 5, count: 1000)
        let right = noise(seed: 6, count: 1000)
        let interleaved = zip(left, right).flatMap { [$0, $1] }

        // When
        let separate = detected([left, right], stride: 1, from: -8, count: 1016)
        let strided = interleaved.withUnsafeBufferPointer { samples in
            detected(pointers: [samples.baseAddress!, samples.baseAddress! + 1], stride: 2, length: 1000, from: -8, count: 1016)
        }

        // Then
        #expect(separate == strided)
    }

    @Test("a sine at a quarter of the rate and 45 degrees, its samples ±1, reads about √2 between them, the Annex points a little above it")
    func readsInterSamplePeak() {
        // Given
        let sound = LoudnessSignal.quarterRateSine()

        // When
        let peak = sound.samples.withUnsafeBufferPointer { samples in
            sut.peak(
                of: [samples.baseAddress!, samples.baseAddress! + 1],
                stride: 2,
                count: sound.frameCount,
                over: 0..<sound.frameCount
            )
        }

        // Then
        let level = 20 * log10(Double(peak))
        #expect(level > 3.0 && level < 3.1, "\(level)")
    }

    @Test("the peak over a range reads the intervals beside it from the samples outside it")
    func readsBesideRange() {
        // Given
        var samples = [Float](repeating: 0, count: 100)
        samples[49] = 1

        // When
        let peak = samples.withUnsafeBufferPointer { samples in
            sut.peak(of: [samples.baseAddress!], stride: 1, count: 100, over: 50..<100)
        }
        let beyond = samples.withUnsafeBufferPointer { samples in
            sut.peak(of: [samples.baseAddress!], stride: 1, count: 100, over: 56..<100)
        }

        // Then
        #expect(peak == 0.97216796875)
        #expect(beyond == 0)
    }

    // MARK: - Private
    private func detected(
        _ channels: [[Float]],
        stride: Int,
        from start: Int,
        count: Int
    ) -> [Float] {
        let left = channels[0]
        let right = channels[1]

        return left.withUnsafeBufferPointer { left in
            right.withUnsafeBufferPointer { right in
                detected(pointers: [left.baseAddress!, right.baseAddress!], stride: stride, length: channels[0].count, from: start, count: count)
            }
        }
    }

    private func detected(
        pointers: [UnsafePointer<Float>],
        stride: Int,
        length: Int,
        from start: Int,
        count: Int
    ) -> [Float] {
        var peaks = [Float](repeating: -1, count: count)
        peaks.withUnsafeMutableBufferPointer { peaks in
            sut.peaks(of: pointers, stride: stride, count: length, from: start, into: peaks)
        }
        return peaks
    }

    // P[n] of one channel by the sums of FRAMES-28, in double precision.
    private func reference(
        _ samples: [Float],
        at sample: Int
    ) -> Double {
        let value = { (index: Int) in index >= 0 && index < samples.count ? Double(samples[index]) : 0 }
        let interpolated = { (phase: [Float], index: Int) in
            abs((0..<12).reduce(0.0) { $0 + Double(phase[$1]) * value(index - $1) })
        }
        let points = InterpolatingFilter.phases.flatMap { phase in
            [interpolated(phase, sample + 5), interpolated(phase, sample + 6)]
        }

        return points.reduce(abs(value(sample)), max)
    }

    private func noise(
        seed: UInt64,
        count: Int
    ) -> [Float] {
        (0..<count).map { Float(SoundSignal.noise(seed: seed).value(channel: 0, at: $0, sampleRate: 48_000)) }
    }
}

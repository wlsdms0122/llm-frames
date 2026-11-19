//
//  CompressorProcessorTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import Frames
@testable import FramesAVFoundation
import Testing

@Suite("CompressorProcessor Tests")
struct CompressorProcessorTests {
    // MARK: - Property
    private static let sampleRate = 48_000.0
    private static let threshold = -18.0
    private static let ratio = 4.0
    // Below, at the edges of and inside a 6 dB knee around -18 dBFS, and above it.
    private static let levels: [Double] = [-40, -24, -21, -19.5, -18, -16.5, -15, -12, 0]

    // MARK: - Initializer
    // MARK: - Test
    @Test("a steady level settles at the gain of the static curve, hard and soft knee", arguments: [0.0, 6.0], levels)
    func followsStaticCurve(
        knee: Double,
        level: Double
    ) {
        // Given
        let sut = CompressorProcessor(compressor: compressor(knee: knee, makeup: 2), sampleRate: Self.sampleRate)
        let amplitude = pow(10, level / 20)
        let input = StereoSample(left: -amplitude / 2, right: amplitude)

        // When
        var output = input
        for sample in 0..<Int(Self.sampleRate) {
            output = sut.process(input, atSample: sample)
        }

        // Then
        let expected = curve(level, knee: knee) - level + 2
        #expect(abs(20 * log10(output.right / amplitude) - expected) < 1e-9, "\(output.right / amplitude)")
        #expect(abs(output.left - output.right * -0.5) < 1e-15)
    }

    @Test("the gain moves toward its target by the attack's time constant and back by the release's")
    func smoothsByTimeConstants() {
        // Given
        let sut = CompressorProcessor(compressor: compressor(knee: 0, makeup: 0), sampleRate: Self.sampleRate)
        let loud = StereoSample(left: pow(10, -6.0 / 20), right: 0)
        let quiet = StereoSample(left: pow(10, -40.0 / 20), right: 0)
        let target = curve(-6, knee: 0) + 6

        // When
        let loudGains = (0..<24_000).map { gain(of: sut.process(loud, atSample: $0), from: loud) }
        let quietGains = (24_000..<48_000).map { gain(of: sut.process(quiet, atSample: $0), from: quiet) }

        // Then
        #expect(abs(loudGains[0] - target * (1 - exp(-1.0 / 480))) < 1e-9)
        #expect(abs(loudGains[479] - target * (1 - exp(-1))) < 1e-9)
        #expect(abs(loudGains[959] - target * (1 - exp(-2))) < 1e-9)
        let held = loudGains[23_999]
        #expect(abs(held - target) < 1e-9)
        #expect(abs(quietGains[4799] - held * exp(-1)) < 1e-9)
    }

    @Test("at rest the compressor's gain is 0 dB, so its first sample above the threshold passes almost whole")
    func startsAtRest() {
        // Given
        let sut = CompressorProcessor(compressor: compressor(knee: 0, makeup: 0), sampleRate: Self.sampleRate)
        let loud = StereoSample(left: 1, right: 1)

        // When
        let output = sut.process(loud, atSample: 96_000)

        // Then
        #expect(abs(gain(of: output, from: loud) - (curve(0, knee: 0) * (1 - exp(-1.0 / 480)))) < 1e-9)
    }

    // MARK: - Private
    private func compressor(
        knee: Double,
        makeup: Double
    ) -> MixCompressor {
        MixCompressor(
            threshold: .constant(Self.threshold),
            ratio: .constant(Self.ratio),
            knee: .constant(knee),
            attack: .constant(0.01),
            release: .constant(0.1),
            makeup: .constant(makeup)
        )
    }

    // The static curve as written: L where 2(L - T) < -W, L + (1/R - 1)(L - T + W/2)² / (2W) where |2(L - T)| ≤ W and W
    // is above 0, and T + (L - T) / R where 2(L - T) > W.
    private func curve(
        _ level: Double,
        knee: Double
    ) -> Double {
        let twice = 2 * (level - Self.threshold)
        if twice < -knee {
            return level
        }
        if knee > 0 && abs(twice) <= knee {
            let rise = level - Self.threshold + knee / 2
            return level + (1 / Self.ratio - 1) * rise * rise / (2 * knee)
        }

        return Self.threshold + (level - Self.threshold) / Self.ratio
    }

    private func gain(
        of output: StereoSample,
        from input: StereoSample
    ) -> Double {
        20 * log10(output.left / input.left)
    }
}

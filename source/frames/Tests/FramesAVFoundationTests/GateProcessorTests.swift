//
//  GateProcessorTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import Frames
@testable import FramesAVFoundation
import Testing

@Suite("GateProcessor Tests")
struct GateProcessorTests {
    // MARK: - Property
    private static let sampleRate = 48_000.0

    private let loud = StereoSample(left: 0.5, right: -0.25)
    private let quiet = StereoSample(left: 0.001, right: 0.002)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a level at the threshold opens the gate from closed by its attack's time constant")
    func opensByAttack() {
        // Given
        let sut = GateProcessor(gate: gate(range: -80), sampleRate: Self.sampleRate)

        // When
        let gains = (0..<4800).map { gain(of: sut.process(loud, atSample: $0), from: loud) }

        // Then
        #expect(abs(gains[0] - -80 * exp(-1.0 / 48)) < 1e-9)
        #expect(abs(gains[47] - -80 * exp(-1)) < 1e-9)
        #expect(abs(gains[4799]) < 1e-9)
    }

    @Test("below the threshold the gate holds the sound down by its range from its first sample")
    func holdsDownByRange() {
        // Given
        let sut = GateProcessor(gate: gate(range: -20), sampleRate: Self.sampleRate)

        // When
        let outputs = (0..<4800).map { sut.process(quiet, atSample: $0) }

        // Then
        #expect(outputs.allSatisfy { abs($0.left - 0.0001) < 1e-15 && abs($0.right - 0.0002) < 1e-15 })
    }

    @Test("the gate stays open for less than `hold` seconds after the last level at the threshold, then releases")
    func holdsThenReleases() {
        // Given
        let sut = GateProcessor(gate: gate(range: -80), sampleRate: Self.sampleRate)
        let lastLoud = 9599

        // When
        let gains = (0..<24_000).map { sample in
            let input = sample <= lastLoud ? loud : quiet
            return gain(of: sut.process(input, atSample: sample), from: input)
        }

        // Then
        let closing = lastLoud + 2400
        #expect(abs(gains[closing - 1]) < 1e-9)
        #expect(gains[closing] < -1e-3)
        #expect(abs(gains[closing + 4799] - -80 * (1 - exp(-1))) < 1e-6)
    }

    // MARK: - Private
    private func gate(range: Double) -> MixGate {
        MixGate(
            threshold: .constant(-30),
            range: .constant(range),
            attack: .constant(0.001),
            hold: .constant(0.05),
            release: .constant(0.1)
        )
    }

    private func gain(
        of output: StereoSample,
        from input: StereoSample
    ) -> Double {
        20 * log10(output.left / input.left)
    }
}

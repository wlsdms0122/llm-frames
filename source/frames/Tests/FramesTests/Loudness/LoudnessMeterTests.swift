//
//  LoudnessMeterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
import FramesTestMedia
import Testing

@testable import Frames

@Suite("LoudnessMeter Tests")
struct LoudnessMeterTests {
    // MARK: - Property
    private let sut = LoudnessMeter()

    // The loudness cases 1 to 5 of EBU Tech 3341, stereo 1 kHz tones, each -23 or -33 LUFS integrated within 0.1 LU.
    private static let integratedCases: [(case: Int, parts: [(seconds: Double, level: Double?)], expected: Double)] = [
        (1, [(20, -23)], -23),
        (2, [(20, -33)], -33),
        (3, [(10, -36), (60, -23), (10, -36)], -23),
        (4, [(10, -72), (10, -36), (60, -23), (10, -36), (10, -72)], -23),
        (5, [(20, -26), (20.1, -20), (20, -26)], -23)
    ]

    // The true-peak cases 15 to 19 of Tech 3341: the period in samples, the amplitude, the start phase in degrees and
    // the expected dBTP, read within +0.2 and -0.4 dB.
    private static let sineCases: [(case: Int, divisor: Double, amplitude: Double, phase: Double, expected: Double)] = [
        (15, 4, 0.5, 0, -6),
        (16, 4, 0.5, 45, -6),
        (17, 6, 0.5, 60, -6),
        (18, 8, 0.5, 67.5, -6),
        (19, 4, 1.41, 45, 3)
    ]

    // The loudness range cases 1 to 4 of EBU Tech 3342, read within 1 LU.
    private static let rangeCases: [(case: Int, parts: [(seconds: Double, level: Double?)], expected: Double)] = [
        (1, [(20, -20), (20, -30)], 10),
        (2, [(20, -20), (20, -15)], 5),
        (3, [(20, -40), (20, -20)], 20),
        (4, [(20, -50), (20, -35), (20, -20), (20, -35), (20, -50)], 15)
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("a sine of 997 Hz at full scale on one channel reads -3.01 LUFS, as BS.1770-5 gives")
    func readsReferenceSine() {
        // Given
        let values = (0..<(10 * 48_000)).map { Float(sin(2 * Double.pi * 997 * Double($0) / 48_000)) }
        let sound = SoundBuffer(sampleRate: 48_000, channels: 2, samples: values.flatMap { [$0, 0] })

        // When
        let loudness = sut.measure(sound).rounded()

        // Then
        #expect(loudness.integrated == -3.01)
        #expect(loudness.momentaryMax == -3.01 && loudness.shortTermMax == -3.01)
        #expect(loudness.samplePeak == 0)
    }

    @Test("the integrated loudness of the Tech 3341 tones lies within 0.1 LU", arguments: integratedCases.indices)
    func readsIntegratedCase(index: Int) throws {
        // Given
        let (number, parts, expected) = Self.integratedCases[index]

        // When
        let loudness = sut.measure(LoudnessSignal.tone(parts))

        // Then
        let integrated = try #require(loudness.integrated)
        #expect(abs(integrated - expected) <= 0.1, "case \(number): \(integrated)")
        if number <= 2 {
            #expect(abs(try #require(loudness.momentaryMax) - expected) <= 0.1)
            #expect(abs(try #require(loudness.shortTermMax) - expected) <= 0.1)
        }
    }

    @Test("a tone moving between -20 and -30 dBFS reads -23 LUFS short-term and momentary at most (Tech 3341 cases 9 and 12)")
    func readsMovingTone() throws {
        // Given
        let shortTerm = LoudnessSignal.tone(Array(repeating: [(1.34, -20), (1.66, -30)], count: 5).flatMap { $0 })
        let momentary = LoudnessSignal.tone(Array(repeating: [(0.18, -20), (0.22, -30)], count: 25).flatMap { $0 })

        // When
        let shortTermMax = try #require(sut.measure(shortTerm).shortTermMax)
        let momentaryMax = try #require(sut.measure(momentary).momentaryMax)

        // Then
        #expect(abs(shortTermMax + 23) <= 0.1, "\(shortTermMax)")
        #expect(abs(momentaryMax + 23) <= 0.1, "\(momentaryMax)")
    }

    @Test("a 3 s tone at -23 dBFS after silence reads -23 LUFS short-term at most wherever it starts (Tech 3341 case 10)")
    func readsShortTermWherever() throws {
        // Given
        let sounds = (0..<20).map { LoudnessSignal.tone([(Double($0) * 0.15, nil), (3, -23), (1, nil)]) }

        // When
        let maxima = try sounds.map { try #require(sut.measure($0).shortTermMax) }

        // Then
        #expect(maxima.allSatisfy { abs($0 + 23) <= 0.1 }, "\(maxima)")
    }

    @Test("a 400 ms tone at -23 dBFS after silence reads -23 LUFS momentary at most wherever it starts (Tech 3341 case 13)")
    func readsMomentaryWherever() throws {
        // Given
        let sounds = (0..<20).map { LoudnessSignal.tone([(Double($0) * 0.02, nil), (0.4, -23), (1, nil)]) }

        // When
        let maxima = try sounds.map { try #require(sut.measure($0).momentaryMax) }

        // Then
        #expect(maxima.allSatisfy { abs($0 + 23) <= 0.1 }, "\(maxima)")
    }

    @Test("the true peak of the Tech 3341 sines lies within +0.2 and -0.4 dB and never below the sample peak", arguments: sineCases.indices)
    func readsTruePeakSine(index: Int) throws {
        // Given
        let (number, divisor, amplitude, phase, expected) = Self.sineCases[index]

        // When
        let loudness = sut.measure(LoudnessSignal.truePeakSine(divisor: divisor, amplitude: amplitude, phase: phase))

        // Then
        let truePeak = try #require(loudness.truePeak)
        #expect(truePeak >= expected - 0.4 && truePeak <= expected + 0.2, "case \(number): \(truePeak)")
        #expect(truePeak >= (try #require(loudness.samplePeak)))
    }

    @Test("the true peak of the Tech 3341 band-limited bursts lies within +0.2 and -0.4 dB of 0 dBTP", arguments: 0..<4)
    func readsTruePeakBurst(offset: Int) throws {
        // Given
        let sound = LoudnessSignal.truePeakBurst(offset: offset)

        // When
        let truePeak = try #require(sut.measure(sound).truePeak)

        // Then
        #expect(truePeak >= -0.4 && truePeak <= 0.2, "case \(20 + offset): \(truePeak)")
    }

    @Test("the loudness range of the Tech 3342 tones lies within 1 LU", arguments: rangeCases.indices)
    func readsRangeCase(index: Int) throws {
        // Given
        let (number, parts, expected) = Self.rangeCases[index]

        // When
        let range = try #require(sut.measure(LoudnessSignal.tone(parts)).range)

        // Then
        #expect(abs(range - expected) <= 1, "case \(number): \(range)")
    }

    @Test("a silent sound reads no measure")
    func readsSilence() {
        // Given
        let sound = SoundBuffer(sampleRate: 48_000, channels: 2, samples: [Float](repeating: 0, count: 2 * 200_000))

        // When
        let loudness = sut.measure(sound)

        // Then
        #expect(loudness == Loudness(
            integrated: nil,
            range: nil,
            momentaryMax: nil,
            shortTermMax: nil,
            truePeak: nil,
            samplePeak: nil
        ))
    }

    @Test("a range shorter than a gating block reads only its peaks, and one shorter than 3 s no short-term or range")
    func readsShortRanges() {
        // Given
        let sound = LoudnessSignal.tone([(4, -20)])

        // When
        let short = sut.measure(sound, over: 48_000..<(48_000 + 19_199))
        let block = sut.measure(sound, over: 48_000..<(48_000 + 19_200))

        // Then
        #expect(short.integrated == nil && short.momentaryMax == nil && short.shortTermMax == nil && short.range == nil)
        #expect(short.truePeak != nil && short.samplePeak != nil)
        #expect(block.integrated != nil && block.momentaryMax != nil)
        #expect(block.shortTermMax == nil && block.range == nil)
    }

    @Test("a range is read as an interval of the whole sound: its filters run from sample 0, and its edges read their neighbours")
    func readsRangeOfWhole() throws {
        // Given
        let loud = LoudnessSignal.tone([(2, -3), (2, -30)], frequency: 30)
        let cut = SoundBuffer(sampleRate: 48_000, channels: 2, samples: Array(loud.samples[(4 * 48_000)...]))
        var step = [Float](repeating: 0, count: 2 * 48_000)
        step[2 * 23_999] = 1

        // When
        let ranged = sut.measure(loud, over: (2 * 48_000)..<(4 * 48_000))
        let alone = sut.measure(cut)
        let edge = sut.measure(SoundBuffer(sampleRate: 48_000, channels: 2, samples: step), over: 24_000..<48_000)

        // Then
        #expect(try #require(ranged.integrated) != (try #require(alone.integrated)))
        #expect(ranged.samplePeak == alone.samplePeak)
        #expect(edge.samplePeak == nil)
        #expect(try #require(edge.truePeak) == 20 * log10(Double(Float(0.97216796875))))
    }

    @Test("the same sound measures the same twice")
    func measuresDeterministically() {
        // Given
        let sound = LoudnessSignal.mix(seed: 7)

        // When
        let first = sut.measure(sound)
        let second = sut.measure(sound)

        // Then
        #expect(first == second)
    }

    @Test("each measure rounds to the nearest hundredth, halves toward positive infinity")
    func roundsHalvesUp() {
        // Given
        let loudness = Loudness(
            integrated: -0.125,
            range: 0.125,
            momentaryMax: -23.004,
            shortTermMax: -23.006,
            truePeak: -0.0001,
            samplePeak: nil
        )

        // When
        let rounded = loudness.rounded()

        // Then
        #expect(rounded.integrated == -0.12 && rounded.range == 0.13)
        #expect(rounded.momentaryMax == -23 && rounded.shortTermMax == -23.01)
        #expect(rounded.truePeak == 0 && rounded.truePeak?.sign == .plus)
        #expect(rounded.samplePeak == nil)
    }

    @Test("a sound that is not stereo at the mix plan's sample rate stops the meter, whose filters and windows are counted at that rate")
    func stopsOnOtherSound() async {
        // When
        // Then
        await #expect(processExitsWith: .failure) {
            _ = LoudnessMeter().measure(SoundBuffer(sampleRate: 44_100, channels: 2, samples: [0, 0]))
        }
        await #expect(processExitsWith: .failure) {
            _ = LoudnessMeter().measure(SoundBuffer(sampleRate: 48_000, channels: 1, samples: [0, 0]))
        }
    }
}

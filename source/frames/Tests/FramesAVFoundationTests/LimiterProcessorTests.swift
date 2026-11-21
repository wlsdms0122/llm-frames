//
//  LimiterProcessorTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
@testable import Frames
@testable import FramesAVFoundation
import FramesTestMedia
import Testing

@Suite("LimiterProcessor Tests")
struct LimiterProcessorTests {
    // MARK: - Property
    private static let sampleRate = 48_000.0

    // The five sounds of the limiter check of FRAMES-24.
    private static let signals: [(name: String, sound: SoundBuffer)] = [
        ("997 Hz sine at amplitude 2", LoudnessSignal.sine(frequency: 997, amplitude: 2, seconds: 5)),
        ("noise bursts", LoudnessSignal.noiseBursts(seed: 1770)),
        ("mix at 8 dBFS", LoudnessSignal.mix(seed: 7)),
        ("quarter rate sine at 45 degrees", LoudnessSignal.quarterRateSine()),
        ("50 Hz sine at amplitude 2", LoudnessSignal.sine(frequency: 50, amplitude: 2, seconds: 5))
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "at a ceiling of -1 every sample is under the ceiling and the true peak at most 0.05 dB over it (FRAMES-24)",
        arguments: signals.indices,
        [0.0015, 0.005, 0.05]
    )
    func holdsCeiling(
        signal: Int,
        lookahead: Double
    ) throws {
        // Given
        let sound = Self.signals[signal].sound

        for release in [0.000001, 0.1, 1] {
            let sut = LimiterProcessor(limiter: limiter(lookahead: lookahead, release: release), sampleRate: Self.sampleRate)

            // When
            let output = limited(sound, by: sut)

            // Then
            let measured = LoudnessMeter().measure(output).rounded()
            let ceiling = Float(pow(10, -1.0 / 20))
            let largest = output.samples.reduce(Float(0)) { max($0, abs($1)) }
            let name = "\(Self.signals[signal].name), lookahead \(lookahead), release \(release)"
            #expect(largest <= ceiling * (1 + 1e-6), "\(name): \(largest)")
            #expect(try #require(measured.samplePeak) <= -1, "\(name)")
            #expect(try #require(measured.truePeak) <= -0.95, "\(name): \(measured.truePeak ?? 0)")
        }
    }

    @Test("the output follows the formula of FRAMES-28 sample for sample, moving values, pre-roll and both ends included")
    func followsFormula() {
        // Given
        let frames = 3000
        let left = (0..<frames).map { Float(1.6 * SoundSignal.noise(seed: 11).value(channel: 0, at: $0, sampleRate: 48_000)) }
        let right = (0..<frames).map { Float(0.4 * sin(2 * Double.pi * 300 * Double($0) / 48_000)) }
        let first = 1000
        let limiter = MixLimiter(
            gain: .envelope([EnvelopePoint(time: 1000 / 48_000.0, value: -3), EnvelopePoint(time: 4000 / 48_000.0, value: 6)]),
            ceiling: .envelope([EnvelopePoint(time: 1500 / 48_000.0, value: -6), EnvelopePoint(time: 3500 / 48_000.0, value: 1)]),
            lookahead: 0.002,
            release: .envelope([EnvelopePoint(time: 1000 / 48_000.0, value: 0.001), EnvelopePoint(time: 4000 / 48_000.0, value: 0.01)])
        )
        let sut = LimiterProcessor(limiter: limiter, sampleRate: Self.sampleRate)

        // When
        var limitedLeft = left
        var limitedRight = right
        limitedLeft.withUnsafeMutableBufferPointer { left in
            limitedRight.withUnsafeMutableBufferPointer { right in
                sut.process([left.baseAddress!, right.baseAddress!], frames: frames, first: first)
            }
        }
        let output = [limitedLeft, limitedRight]

        // Then
        let expected = reference([left, right], limiter: limiter, first: first)
        let deviation = (0..<2).flatMap { channel in
            (0..<frames).map { abs(Double(output[channel][$0]) - expected[channel][$0]) }
        }.max()!
        #expect(deviation < 1e-5, "\(deviation)")
    }

    @Test("a sound under the ceiling passes raised by `gain` and nothing else, and silence stays silent")
    func passesUnderCeiling() {
        // Given
        let quiet = LoudnessSignal.sine(frequency: 440, amplitude: 0.1, seconds: 0.5)
        let silence = SoundBuffer(sampleRate: 48_000, channels: 2, samples: [Float](repeating: 0, count: 48_000))
        let raised = MixLimiter(gain: .constant(6), ceiling: .constant(-1), lookahead: 0.005, release: .constant(0.1))

        // When
        let passed = limited(quiet, by: LimiterProcessor(limiter: limiter(lookahead: 0.005, release: 0.1), sampleRate: Self.sampleRate))
        let louder = limited(quiet, by: LimiterProcessor(limiter: raised, sampleRate: Self.sampleRate))
        let silent = limited(silence, by: LimiterProcessor(limiter: raised, sampleRate: Self.sampleRate))

        // Then
        #expect(passed.samples == quiet.samples)
        let scale = pow(10, 6.0 / 20)
        #expect(zip(louder.samples, quiet.samples).allSatisfy { $0 == Float(Double($1) * scale) })
        #expect(silent.samples == silence.samples)
    }

    @Test("a peak is met along a ramp of `lookahead` that ends at it, with no latency, and the gain is linked across channels")
    func rampsBeforePeak() {
        // Given
        let delay = 240
        let peak = 4800
        var left = (0..<9600).map { Float(0.1 * sin(2 * Double.pi * 1000 * Double($0) / 48_000)) }
        left[peak] = 2
        let right = left.map { $0 / 2 }
        let sound = SoundBuffer(sampleRate: 48_000, channels: 2, samples: zip(left, right).flatMap { [$0, $1] })
        let sut = LimiterProcessor(limiter: limiter(lookahead: 0.005, release: 0.1), sampleRate: Self.sampleRate)

        // When
        let output = limited(sound, by: sut)

        // Then
        let untouched = peak - delay - 7
        #expect((0..<untouched).allSatisfy { output.samples[2 * $0] == sound.samples[2 * $0] })
        let ramp = peak - delay / 2 + 5
        #expect(abs(output.samples[2 * ramp]) < abs(sound.samples[2 * ramp]))
        #expect(abs(output.samples[2 * peak]) <= Float(pow(10, -1.0 / 20)) * (1 + 1e-6))
        #expect(abs(output.samples[2 * peak]) > 0.8)
        #expect((0..<9600).allSatisfy { output.samples[2 * $0 + 1] == output.samples[2 * $0] / 2 })
    }

    @Test("a ceiling above 0 limits at 0 dBTP, and a release at or below 0 lets the gain back up at once")
    func clampsSampledValues() {
        // Given
        let loud = LoudnessSignal.tone([(0.2, 6), (0.2, -20)])
        let clamped = MixLimiter(gain: .constant(0), ceiling: .constant(3), lookahead: 0.005, release: .constant(0.1))
        let zero = MixLimiter(gain: .constant(0), ceiling: .constant(0), lookahead: 0.005, release: .constant(0.1))
        let instant = MixLimiter(gain: .constant(0), ceiling: .constant(-1), lookahead: 0.005, release: .constant(-1))

        // When
        let above = limited(loud, by: LimiterProcessor(limiter: clamped, sampleRate: Self.sampleRate))
        let atZero = limited(loud, by: LimiterProcessor(limiter: zero, sampleRate: Self.sampleRate))
        let released = limited(loud, by: LimiterProcessor(limiter: instant, sampleRate: Self.sampleRate))

        // Then
        #expect(above.samples == atZero.samples)
        let settled = 2 * (9600 + 240 + 12)
        #expect(Array(released.samples[settled...]) == Array(loud.samples[settled...]))
    }

    @Test("the same sound limits to the same samples twice")
    func limitsDeterministically() {
        // Given
        let sound = LoudnessSignal.mix(seed: 7)

        // When
        let first = limited(sound, by: LimiterProcessor(limiter: limiter(lookahead: 0.005, release: 0.1), sampleRate: Self.sampleRate))
        let second = limited(sound, by: LimiterProcessor(limiter: limiter(lookahead: 0.005, release: 0.1), sampleRate: Self.sampleRate))

        // Then
        #expect(first.samples == second.samples)
    }

    // MARK: - Private
    private func limiter(
        lookahead: Double,
        release: Double
    ) -> MixLimiter {
        MixLimiter(gain: .constant(0), ceiling: .constant(-1), lookahead: lookahead, release: .constant(release))
    }

    // The interleaved stereo `sound` through `limiter` as one sound from sequence sample 0.
    private func limited(
        _ sound: SoundBuffer,
        by limiter: LimiterProcessor
    ) -> SoundBuffer {
        var left = stride(from: 0, to: sound.samples.count, by: 2).map { sound.samples[$0] }
        var right = stride(from: 1, to: sound.samples.count, by: 2).map { sound.samples[$0] }
        left.withUnsafeMutableBufferPointer { left in
            right.withUnsafeMutableBufferPointer { right in
                limiter.process([left.baseAddress!, right.baseAddress!], frames: sound.frameCount, first: 0)
            }
        }

        return SoundBuffer(sampleRate: 48_000, channels: 2, samples: zip(left, right).flatMap { [$0, $1] })
    }

    // The limiter's eight steps as FRAMES-28 writes them, in double precision, one array a step.
    private func reference(
        _ channels: [[Float]],
        limiter: MixLimiter,
        first: Int
    ) -> [[Double]] {
        let count = channels[0].count
        let delay = Int((limiter.lookahead * Self.sampleRate).rounded())
        let value = { (value: MixValue, sample: Int) -> Double in
            var cursor = EnvelopeCursor(value: value)
            return cursor.value(at: Double(first + min(max(sample, 0), count - 1)) / Self.sampleRate)
        }
        let raised = channels.map { channel in
            channel.enumerated().map { Double($1) * pow(10, value(limiter.gain, $0) / 20) }
        }
        let sample = { (channel: Int, index: Int) in index >= 0 && index < count ? raised[channel][index] : 0 }
        let interpolated = { (channel: Int, phase: [Float], index: Int) in
            abs((0..<12).reduce(0.0) { $0 + Double(phase[$1]) * sample(channel, index - $1) })
        }
        let detector = { (index: Int) in
            (0..<2).flatMap { channel in
                [abs(sample(channel, index))] + InterpolatingFilter.phases.flatMap { phase in
                    [interpolated(channel, phase, index + 5), interpolated(channel, phase, index + 6)]
                }
            }.max()!
        }
        let target = { (index: Int) -> Double in
            let peak = detector(index)
            return peak > 0 ? min(0, min(value(limiter.ceiling, index), 0) - 20 * log10(peak)) : 0
        }
        let targets = Dictionary(uniqueKeysWithValues: (-delay..<(count + delay)).map { ($0, target($0)) })
        let holds = (-delay..<count).map { index in (index...(index + delay)).map { targets[$0]! }.min()! }
        var releases = [Double]()
        var previous = 0.0
        for (offset, hold) in holds.enumerated() {
            let release = value(limiter.release, offset - delay)
            let factor = release > 0 ? exp(-1 / (release * Self.sampleRate)) : 0
            previous = hold <= previous ? hold : factor * previous + (1 - factor) * hold
            releases.append(previous)
        }
        let gains = (0..<count).map { index in releases[index...(index + delay)].reduce(0, +) / Double(delay + 1) }

        return raised.map { channel in channel.enumerated().map { $1 * pow(10, gains[$0] / 20) } }
    }
}

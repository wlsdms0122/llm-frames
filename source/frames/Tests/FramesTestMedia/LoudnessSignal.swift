//
//  LoudnessSignal.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/21/26.
//

import Accelerate
import Foundation
import Frames

// Stereo test sounds at 48 kHz for the loudness meter and the limiter: the synthetic cases of EBU Tech 3341 and 3342,
// and the five sounds of the limiter check of FRAMES-24.
package struct LoudnessSignal: Sendable {
    // MARK: - Property
    package static let sampleRate = 48_000

    // MARK: - Initializer
    // MARK: - Public
    // A 1 kHz sine on both channels, phase continuous across its parts, each part `seconds` long at `level` dBFS or
    // silent where `level` is nil, as the tones of Tech 3341 and 3342 are.
    package static func tone(
        _ parts: [(seconds: Double, level: Double?)],
        frequency: Double = 1000
    ) -> SoundBuffer {
        let amplitudes = parts.flatMap { part in
            [Double](
                repeating: part.level.map { pow(10, $0 / 20) } ?? 0,
                count: Int((part.seconds * Double(sampleRate)).rounded())
            )
        }
        let values = amplitudes.enumerated().map { index, amplitude in
            amplitude * sin(2 * .pi * frequency * Double(index) / Double(sampleRate))
        }

        return stereo(left: values, right: values)
    }

    // A sine of a period of `divisor` samples, `amplitude` and a start phase in degrees on both channels, 1 s long with
    // 10 ms raised cosine ramps, as the true-peak cases 15 to 19 of Tech 3341.
    package static func truePeakSine(
        divisor: Double,
        amplitude: Double,
        phase: Double
    ) -> SoundBuffer {
        let values = (0..<sampleRate).map { index in
            amplitude * sin(2 * .pi * Double(index) / divisor + phase * .pi / 180)
        }

        return stereo(left: tapered(values, ramp: 480), right: tapered(values, ramp: 480))
    }

    // The true-peak cases 20 to 23 of Tech 3341: at 4 times the rate, 0.5 s of a sine at a sixth of the rate at 0.5,
    // one period of a sine at a quarter of the rate at full scale and 0.5 s more of the first, low-passed at 21 kHz by
    // a 4095-tap Kaiser windowed sinc with a β of 12, then every fourth sample from `offset`, with 5 ms ramps.
    package static func truePeakBurst(offset: Int) -> SoundBuffer {
        let rate = 4 * sampleRate
        let half = (0..<(rate / 2)).map { 0.5 * sin(2 * .pi * Double($0) / 24) }
        let period = (0..<16).map { sin(2 * .pi * Double($0) / 16) }
        let source = half + period + half
        let taps = lowPass(count: 4095, cutoff: 21_000 / Double(rate / 2), beta: 12)
        let padding = [Double](repeating: 0, count: taps.count / 2)
        let padded = padding + source + padding
        let values = stride(from: offset, to: source.count, by: 4).map { index in
            var value = 0.0
            padded.withUnsafeBufferPointer { samples in
                vDSP_dotprD(samples.baseAddress! + index, 1, taps, 1, &value, vDSP_Length(taps.count))
            }
            return value
        }

        return stereo(left: tapered(values, ramp: 240), right: tapered(values, ramp: 240))
    }

    // A sine of `frequency` at `amplitude`, the same on both channels.
    package static func sine(
        frequency: Double,
        amplitude: Double,
        seconds: Double
    ) -> SoundBuffer {
        let values = (0..<Int(seconds * Double(sampleRate))).map { index in
            amplitude * sin(2 * .pi * frequency * Double(index) / Double(sampleRate))
        }

        return stereo(left: values, right: values)
    }

    // White noise uniform in [-2, 2], drawn on each channel on its own, over the first half of each second and silent
    // over the second half, 10 s long.
    package static func noiseBursts(seed: UInt64) -> SoundBuffer {
        let count = 10 * sampleRate
        let noise = SoundSignal.noise(seed: seed)
        let channel = { (channel: Int) in
            (0..<count).map { index in
                (index / (sampleRate / 2)).isMultiple(of: 2)
                    ? 2 * noise.value(channel: channel, at: index, sampleRate: sampleRate)
                    : 0
            }
        }

        return stereo(left: channel(0), right: channel(1))
    }

    // The mix of the limiter check: five sines on each channel, a kick every half second on both, Gaussian noise of
    // standard deviation 0.08 on each channel on its own, scaled to a sample peak of 8 dBFS, 10 s long.
    package static func mix(seed: UInt64) -> SoundBuffer {
        let count = 10 * sampleRate
        let left: [(Double, Double, Double)] = [(110, 0.3, 0), (220, 0.25, 1), (330, 0.2, 2), (1760, 0.1, 0.5), (3520, 0.05, 0)]
        let right: [(Double, Double, Double)] = [(110, 0.3, 0.3), (277, 0.25, 1), (440, 0.2, 2), (2637, 0.1, 0.5), (5274, 0.05, 0)]
        let channel = { (channel: Int, sines: [(Double, Double, Double)]) in
            (0..<count).map { index in
                let time = Double(index) / Double(sampleRate)
                let since = time.truncatingRemainder(dividingBy: 0.5)
                let kick = 0.9 * exp(-since / 0.06) * sin(2 * .pi * 60 * since)
                let tones = sines.reduce(0.0) { sum, sine in
                    sum + sine.1 * sin(2 * .pi * sine.0 * time + sine.2)
                }
                return tones + kick + 0.08 * gaussian(seed: seed, channel: channel, at: index)
            }
        }
        let values = (channel(0, left), channel(1, right))
        let peak = zip(values.0, values.1).reduce(0.0) { max($0, abs($1.0), abs($1.1)) }
        let scale = pow(10, 8.0 / 20) / peak

        return stereo(left: values.0.map { $0 * scale }, right: values.1.map { $0 * scale })
    }

    // √2 sin(2π n / 4 + π / 4), whose samples are ±1 and whose peak between them is √2, the same on both channels, 2 s
    // long (case 19 of Tech 3341 at full scale).
    package static func quarterRateSine() -> SoundBuffer {
        let values = (0..<(2 * sampleRate)).map { index in
            2.0.squareRoot() * sin(2 * .pi * Double(index) / 4 + .pi / 4)
        }

        return stereo(left: values, right: values)
    }

    // MARK: - Private
    private static func stereo(
        left: [Double],
        right: [Double]
    ) -> SoundBuffer {
        SoundBuffer(
            sampleRate: Double(sampleRate),
            channels: 2,
            samples: zip(left, right).flatMap { [Float($0), Float($1)] }
        )
    }

    // Raised cosine ramps `ramp` samples long at both ends.
    private static func tapered(
        _ values: [Double],
        ramp: Int
    ) -> [Double] {
        values.enumerated().map { index, value in
            let edge = min(index, values.count - 1 - index)
            guard edge < ramp else { return value }

            return value * (0.5 - 0.5 * cos(.pi * Double(edge) / Double(ramp)))
        }
    }

    // A low-pass windowed sinc of `count` taps, `cutoff` a fraction of the Nyquist rate, with a Kaiser window of `beta`,
    // scaled to a gain of 1 at 0 Hz.
    private static func lowPass(
        count: Int,
        cutoff: Double,
        beta: Double
    ) -> [Double] {
        let middle = Double(count - 1) / 2
        let taps = (0..<count).map { index in
            let offset = Double(index) - middle
            let sinc = offset == 0 ? 1 : sin(.pi * cutoff * offset) / (.pi * cutoff * offset)
            let window = besselI0(beta * (1 - (offset / middle) * (offset / middle)).squareRoot()) / besselI0(beta)
            return cutoff * sinc * window
        }
        let sum = taps.reduce(0, +)

        return taps.map { $0 / sum }
    }

    // The modified Bessel function of the first kind of order 0, by its power series.
    private static func besselI0(_ value: Double) -> Double {
        var sum = 1.0
        var term = 1.0
        var order = 1.0
        while term > sum * 1e-17 {
            term *= (value / (2 * order)) * (value / (2 * order))
            sum += term
            order += 1
        }
        return sum
    }

    // A standard normal value by the Box-Muller transform of two uniform values of the seed's noise.
    private static func gaussian(
        seed: UInt64,
        channel: Int,
        at index: Int
    ) -> Double {
        let noise = SoundSignal.noise(seed: seed)
        let first = (noise.value(channel: channel, at: 2 * index, sampleRate: sampleRate) + 1) / 2
        let second = (noise.value(channel: channel, at: 2 * index + 1, sampleRate: sampleRate) + 1) / 2

        return (-2 * log(max(first, .leastNonzeroMagnitude))).squareRoot() * cos(2 * .pi * second)
    }
}

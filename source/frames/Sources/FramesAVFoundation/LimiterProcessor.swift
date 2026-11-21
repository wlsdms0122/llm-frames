//
//  LimiterProcessor.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import Foundation
import Frames

// The limiter of FRAMES-28 over a whole sound of N samples a channel, in place. It raises the sound by `gain` and turns
// it down by g[n], the mean over the D + 1 samples that end at n of r, the release-smoothed running minimum h over
// [n, n + D] of the target c = min(0, `ceiling` - 20 log10 P), with P the detector shared with the meter and
// D = round(`lookahead` × 48000). It runs from sample -D at rest, r[-D - 1] = 0 dB, and reads silence before sample 0
// and from N on, so its output is aligned with its input. A moving value is read at the sequence time of each sample,
// holding its value at the first or last sample outside the sound.
final class LimiterProcessor {
    // MARK: - Property
    private let sampleRate: Double
    private let delay: Int
    private var gain: EnvelopeCursor
    private var ceiling: EnvelopeCursor
    private var release: EnvelopeCursor
    private let detector = PeakDetector()

    // MARK: - Initializer
    init(
        limiter: MixLimiter,
        sampleRate: Double
    ) {
        self.sampleRate = sampleRate
        self.delay = Int((limiter.lookahead * sampleRate).rounded())
        self.gain = EnvelopeCursor(value: limiter.gain)
        self.ceiling = EnvelopeCursor(value: limiter.ceiling)
        self.release = EnvelopeCursor(value: limiter.release)
    }

    // MARK: - Public
    // Limits `frames` samples of each of `channels`, whose frame 0 plays at sequence sample `first`. It is made at rest
    // for one sound and takes it once.
    func process(
        _ channels: [UnsafeMutablePointer<Float>],
        frames: Int,
        first: Int
    ) {
        guard frames > 0 else { return }

        applyGain(to: channels, frames: frames, first: first)

        // One row over n from -D to N + D - 1, at index n + D: first P, then c in place, then h over n below N, then
        // r, then g over n from 0 at index n.
        let row = UnsafeMutableBufferPointer<Float>.allocate(capacity: frames + 2 * delay)
        defer { row.deallocate() }

        detector.peaks(
            of: channels.map { UnsafePointer($0) },
            stride: 1,
            count: frames,
            from: -delay,
            into: row
        )
        target(row, frames: frames, first: first)
        hold(row)
        smoothRelease(row, frames: frames, first: first)
        smoothRamp(row, frames: frames)

        for frame in 0..<frames {
            let scale = pow(10, Double(row[frame]) / 20)
            for channel in channels {
                channel[frame] = Float(Double(channel[frame]) * scale)
            }
        }
    }

    // MARK: - Private
    // x'_c[n] = 10^(gain[n] / 20) × x_c[n].
    private func applyGain(
        to channels: [UnsafeMutablePointer<Float>],
        frames: Int,
        first: Int
    ) {
        for frame in 0..<frames {
            let scale = pow(10, gain.value(at: time(of: frame, frames: frames, first: first)) / 20)
            for channel in channels {
                channel[frame] = Float(Double(channel[frame]) * scale)
            }
        }
    }

    // c[n] = min(0, ceiling[n] - 20 log10 P[n]), with a ceiling above 0 taken as 0 and a silent P[n] as 0 dB.
    private func target(
        _ row: UnsafeMutableBufferPointer<Float>,
        frames: Int,
        first: Int
    ) {
        for index in 0..<row.count {
            let ceiling = min(ceiling.value(at: time(of: index - delay, frames: frames, first: first)), 0)
            let peak = Double(row[index])
            row[index] = peak > 0 ? Float(min(0, ceiling - 20 * log10(peak))) : 0
        }
    }

    // h[n] = the minimum of c over [n, n + D], for n from -D to N - 1, by a scan from the end that keeps the window's
    // ascending minima.
    private func hold(_ row: UnsafeMutableBufferPointer<Float>) {
        let capacity = delay + 2
        let indices = UnsafeMutableBufferPointer<Int>.allocate(capacity: capacity)
        let values = UnsafeMutableBufferPointer<Float>.allocate(capacity: capacity)
        defer {
            indices.deallocate()
            values.deallocate()
        }

        var head = 0
        var tail = 0
        for index in stride(from: row.count - 1, through: 0, by: -1) {
            let value = row[index]
            while tail > head && values[(tail - 1) % capacity] >= value {
                tail -= 1
            }
            indices[tail % capacity] = index
            values[tail % capacity] = value
            tail += 1
            while indices[head % capacity] > index + delay {
                head += 1
            }
            if index < row.count - delay {
                row[index] = values[head % capacity]
            }
        }
    }

    // r[n] = h[n] where h[n] ≤ r[n - 1], and β r[n - 1] + (1 - β) h[n] otherwise, β = exp(-1 / (release[n] × 48000)),
    // from r[-D - 1] = 0. A release at or below 0 follows h at once.
    private func smoothRelease(
        _ row: UnsafeMutableBufferPointer<Float>,
        frames: Int,
        first: Int
    ) {
        var previous = 0.0
        for index in 0..<(frames + delay) {
            let release = release.value(at: time(of: index - delay, frames: frames, first: first))
            let hold = Double(row[index])
            if hold <= previous {
                previous = hold
            } else {
                let factor = release > 0 ? exp(-1 / (release * sampleRate)) : 0
                previous = factor * previous + (1 - factor) * hold
            }
            row[index] = Float(previous)
        }
    }

    // g[n] = the mean of r over [n - D, n], for n from 0 to N - 1, written at index n.
    private func smoothRamp(
        _ row: UnsafeMutableBufferPointer<Float>,
        frames: Int
    ) {
        var sum = 0.0
        for index in 0..<delay {
            sum += Double(row[index])
        }
        for frame in 0..<frames {
            let oldest = Double(row[frame])
            sum += Double(row[frame + delay])
            row[frame] = Float(sum / Double(delay + 1))
            sum -= oldest
        }
    }

    // The sequence time a moving value is read at for sample n of the sound, n held inside [0, N - 1].
    private func time(
        of sample: Int,
        frames: Int,
        first: Int
    ) -> Double {
        Double(first + min(max(sample, 0), frames - 1)) / sampleRate
    }
}

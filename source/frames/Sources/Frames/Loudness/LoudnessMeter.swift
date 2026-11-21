//
//  LoudnessMeter.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

import Accelerate
import Foundation

// The loudness meter of FRAMES-28 over stereo sound at 48 kHz: ITU-R BS.1770-5 integrated loudness and true peak, EBU
// Tech 3341 momentary and short-term maxima and EBU Tech 3342 loudness range, with the sample peak. It reads a range of
// a whole sound: the K-weighting runs from the sound's sample 0, and each measure reads only the blocks, windows,
// samples and interpolated points of the range.
package struct LoudnessMeter: Sendable {
    // MARK: - Property
    // The step of the gating blocks and the short-term values of the range, 100 ms.
    private static let step = 4800
    // A gating block and a momentary window, 400 ms.
    private static let block = 19_200
    // A short-term window, 3 s.
    private static let shortTerm = 144_000

    private let detector = PeakDetector()

    // MARK: - Initializer
    package init() { }

    // MARK: - Public
    // The measures of the whole sound.
    package func measure(_ sound: SoundBuffer) -> Loudness {
        measure(sound, over: 0..<sound.frameCount)
    }

    // The measures of the samples in `range`, which lies in the sound.
    package func measure(
        _ sound: SoundBuffer,
        over range: Range<Int>
    ) -> Loudness {
        sound.samples.withUnsafeBufferPointer { samples in
            let powers = weightedPowers(of: samples, over: range)
            let channels = [samples.baseAddress!, samples.baseAddress! + 1]
            let truePeak = range.isEmpty
                ? 0
                : detector.peak(of: channels, stride: 2, count: sound.frameCount, over: range)
            var samplePeak: Float = 0
            if !range.isEmpty {
                vDSP_maxmgv(samples.baseAddress! + 2 * range.lowerBound, 1, &samplePeak, vDSP_Length(2 * range.count))
            }

            return Loudness(
                integrated: integrated(of: powers.steps),
                range: loudnessRange(of: powers.steps),
                momentaryMax: loudness(ofSum: powers.momentaryMax, length: Self.block),
                shortTermMax: loudness(ofSum: powers.shortTermMax, length: Self.shortTerm),
                truePeak: decibels(truePeak),
                samplePeak: decibels(samplePeak)
            )
        }
    }

    // MARK: - Private
    // One pass of the K-weighting from sample 0 to the end of `range`, summing y_L[n]² + y_R[n]² over each 100 ms step
    // from the range's start that lies in it, and the largest sum over a momentary and over a short-term window
    // starting at any sample of the range, 0 where there is none.
    private func weightedPowers(
        of samples: UnsafeBufferPointer<Float>,
        over range: Range<Int>
    ) -> (steps: [Double], momentaryMax: Double, shortTermMax: Double) {
        var left = KWeightingFilter()
        var right = KWeightingFilter()
        for frame in 0..<range.lowerBound {
            _ = left.process(Double(samples[2 * frame]))
            _ = right.process(Double(samples[2 * frame + 1]))
        }

        var steps = [Double]()
        steps.reserveCapacity(range.count / Self.step)
        var history = [Double](repeating: 0, count: Self.shortTerm)
        var step = 0.0
        var momentary = 0.0
        var shortTerm = 0.0
        var momentaryMax = 0.0
        var shortTermMax = 0.0
        history.withUnsafeMutableBufferPointer { history in
            for offset in 0..<range.count {
                let frame = range.lowerBound + offset
                let weightedLeft = left.process(Double(samples[2 * frame]))
                let weightedRight = right.process(Double(samples[2 * frame + 1]))
                let power = weightedLeft * weightedLeft + weightedRight * weightedRight

                step += power
                if (offset + 1) % Self.step == 0 {
                    steps.append(step)
                    step = 0
                }

                let slot = offset % Self.shortTerm
                momentary += power
                shortTerm += power
                if offset >= Self.block {
                    momentary -= history[(offset - Self.block) % Self.shortTerm]
                }
                if offset >= Self.shortTerm {
                    shortTerm -= history[slot]
                }
                history[slot] = power
                if offset + 1 >= Self.block {
                    momentaryMax = max(momentaryMax, momentary)
                }
                if offset + 1 >= Self.shortTerm {
                    shortTermMax = max(shortTermMax, shortTerm)
                }
            }
        }

        return (steps, momentaryMax, shortTermMax)
    }

    // BS.1770-5 gated loudness over the blocks of four steps at a step apart.
    private func integrated(of steps: [Double]) -> Double? {
        let blocks = windows(of: steps, steps: Self.block / Self.step).map { $0 / Double(Self.block) }
        let absolute = blocks.filter { power in loudness(ofPower: power).map { $0 > -70 } ?? false }
        guard !absolute.isEmpty else { return nil }

        let gate = -0.691 + 10 * log10(absolute.reduce(0, +) / Double(absolute.count)) - 10
        let gated = absolute.filter { power in loudness(ofPower: power).map { $0 > gate } ?? false }

        return -0.691 + 10 * log10(gated.reduce(0, +) / Double(gated.count))
    }

    // EBU Tech 3342 loudness range over the short-term values at a step apart.
    private func loudnessRange(of steps: [Double]) -> Double? {
        let values = windows(of: steps, steps: Self.shortTerm / Self.step).compactMap { sum in
            loudness(ofSum: sum, length: Self.shortTerm)
        }
        let absolute = values.filter { $0 >= -70 }
        guard !absolute.isEmpty else { return nil }

        let gate = 10 * log10(absolute.reduce(0) { $0 + pow(10, $1 / 10) } / Double(absolute.count)) - 20
        let gated = absolute.filter { $0 >= gate }.sorted()
        let percentile = { (percent: Double) in
            gated[Int((Double(gated.count - 1) * percent / 100 + 1 + 0.5).rounded(.down)) - 1]
        }

        return percentile(95) - percentile(10)
    }

    // The sum over each run of `steps` steps in a row, one for each step the run can start at.
    private func windows(
        of sums: [Double],
        steps: Int
    ) -> [Double] {
        guard sums.count >= steps else { return [] }

        return (0...(sums.count - steps)).map { start in
            sums[start..<(start + steps)].reduce(0, +)
        }
    }

    // The loudness of a window whose y_L² + y_R² sum to `sum` over `length` samples, nil for a silent one.
    private func loudness(
        ofSum sum: Double,
        length: Int
    ) -> Double? {
        loudness(ofPower: sum / Double(length))
    }

    // -0.691 + 10 log10(z_L + z_R), nil for a silent window, which lies below every gate.
    private func loudness(ofPower power: Double) -> Double? {
        guard power > 0 else { return nil }

        return -0.691 + 10 * log10(power)
    }

    private func decibels(_ peak: Float) -> Double? {
        guard peak > 0 else { return nil }

        return 20 * log10(Double(peak))
    }
}

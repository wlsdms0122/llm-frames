//
//  CompressorProcessor.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import Frames

// A feed-forward compressor on the linked peak level. Its gain curve y(L) is the identity below the knee,
// T + (L - T) / R above it, and the quadratic L + (1/R - 1)(L - T + W/2)² / (2W) across a knee of width W above 0. It
// smooths the target y(L) - L, attacking while the target is below the gain it applies and releasing otherwise, from
// 0 dB at rest.
final class CompressorProcessor: AudioOperationProcessor {
    // MARK: - Property
    private let sampleRate: Double
    private var threshold: EnvelopeCursor
    private var ratio: EnvelopeCursor
    private var knee: EnvelopeCursor
    private var attack: EnvelopeCursor
    private var release: EnvelopeCursor
    private var makeup: EnvelopeCursor
    private var smoother: GainSmoother

    // MARK: - Initializer
    init(
        compressor: MixCompressor,
        sampleRate: Double
    ) {
        self.sampleRate = sampleRate
        self.threshold = EnvelopeCursor(value: compressor.threshold)
        self.ratio = EnvelopeCursor(value: compressor.ratio)
        self.knee = EnvelopeCursor(value: compressor.knee)
        self.attack = EnvelopeCursor(value: compressor.attack)
        self.release = EnvelopeCursor(value: compressor.release)
        self.makeup = EnvelopeCursor(value: compressor.makeup)
        self.smoother = GainSmoother(gain: 0, sampleRate: sampleRate)
    }

    // MARK: - Lifecycle
    func process(
        _ input: StereoSample,
        atSample sample: Int
    ) -> StereoSample {
        let time = Double(sample) / sampleRate
        let threshold = threshold.value(at: time)
        let ratio = max(ratio.value(at: time), 1)
        let knee = max(knee.value(at: time), 0)
        let attack = attack.value(at: time)
        let release = release.value(at: time)
        let makeup = makeup.value(at: time)

        let level = input.level
        let target = level.isFinite ? curve(level, threshold: threshold, ratio: ratio, knee: knee) - level : 0
        smoother.step(toward: target, timeConstant: target < smoother.gain ? attack : release)

        return input.scaled(by: pow(10, (smoother.gain + makeup) / 20))
    }

    // MARK: - Public
    // MARK: - Private
    private func curve(
        _ level: Double,
        threshold: Double,
        ratio: Double,
        knee: Double
    ) -> Double {
        let over = 2 * (level - threshold)
        guard knee > 0, abs(over) <= knee else {
            return over < -knee ? level : threshold + (level - threshold) / ratio
        }

        let rise = level - threshold + knee / 2

        return level + (1 / ratio - 1) * rise * rise / (2 * knee)
    }
}

//
//  GateProcessor.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import Frames

// A noise gate on the linked peak level. It is open at a sample whose level reaches the threshold and for less than
// `hold` seconds after the last such sample, its target 0 dB open and `range` closed. It smooths the target,
// attacking while the target is above the gain it applies and releasing otherwise, from closed at rest.
final class GateProcessor: AudioOperationProcessor {
    // MARK: - Property
    private let sampleRate: Double
    private var threshold: EnvelopeCursor
    private var range: EnvelopeCursor
    private var attack: EnvelopeCursor
    private var hold: EnvelopeCursor
    private var release: EnvelopeCursor
    private var smoother: GainSmoother?
    private var lastAboveThreshold: Int?

    // MARK: - Initializer
    init(
        gate: MixGate,
        sampleRate: Double
    ) {
        self.sampleRate = sampleRate
        self.threshold = EnvelopeCursor(value: gate.threshold)
        self.range = EnvelopeCursor(value: gate.range)
        self.attack = EnvelopeCursor(value: gate.attack)
        self.hold = EnvelopeCursor(value: gate.hold)
        self.release = EnvelopeCursor(value: gate.release)
    }

    // MARK: - Lifecycle
    func process(
        _ input: StereoSample,
        atSample sample: Int
    ) -> StereoSample {
        let time = Double(sample) / sampleRate
        let threshold = threshold.value(at: time)
        let range = min(range.value(at: time), 0)
        let attack = attack.value(at: time)
        let hold = hold.value(at: time)
        let release = release.value(at: time)

        if input.level >= threshold {
            lastAboveThreshold = sample
        }
        let isOpen = lastAboveThreshold.map { sample == $0 || Double(sample - $0) / sampleRate < hold } ?? false
        let target = isOpen ? 0 : range
        var smoother = smoother ?? GainSmoother(gain: range, sampleRate: sampleRate)
        smoother.step(toward: target, timeConstant: target > smoother.gain ? attack : release)
        self.smoother = smoother

        return input.scaled(by: pow(10, smoother.gain / 20))
    }

    // MARK: - Public
    // MARK: - Private
}

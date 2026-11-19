//
//  BiquadFilter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/19/26.
//

import Frames

// One `eq` band on both channels, each filtered on its own. A band whose values hold computes its coefficients once;
// one whose values move computes them again every `updateInterval` samples from the values at that sample.
struct BiquadFilter: Sendable {
    // MARK: - Property
    private static let updateInterval = 32

    private let type: MixBandType
    private let sampleRate: Double
    private let isMoving: Bool
    private var frequency: EnvelopeCursor
    private var gain: EnvelopeCursor
    private var q: EnvelopeCursor
    private var coefficients: BiquadCoefficients?
    private var samplesToUpdate = 0
    private var left = BiquadState()
    private var right = BiquadState()

    // MARK: - Initializer
    init(
        band: MixBand,
        sampleRate: Double
    ) {
        self.type = band.type
        self.sampleRate = sampleRate
        self.isMoving = band.frequency.isMoving || band.gain?.isMoving == true || band.q.isMoving
        self.frequency = EnvelopeCursor(value: band.frequency)
        self.gain = EnvelopeCursor(value: band.gain ?? .constant(0))
        self.q = EnvelopeCursor(value: band.q)
    }

    // MARK: - Public
    mutating func process(
        _ input: StereoSample,
        atSample sample: Int
    ) -> StereoSample {
        let coefficients = coefficients(atSample: sample)

        return StereoSample(
            left: left.filter(input.left, by: coefficients),
            right: right.filter(input.right, by: coefficients)
        )
    }

    // The coefficients the sample `sample` is filtered by, which `process` reads once per sample in order. A value an
    // ease carries past its range is clamped to it: the frequency to above 0 and below half the sample rate, the q to
    // above 0.
    mutating func coefficients(atSample sample: Int) -> BiquadCoefficients {
        if let coefficients, !isMoving {
            return coefficients
        }
        if let coefficients, samplesToUpdate > 0 {
            samplesToUpdate -= 1
            return coefficients
        }

        let time = Double(sample) / sampleRate
        let nyquist = sampleRate / 2
        let coefficients = BiquadCoefficients(
            type: type,
            frequency: min(max(frequency.value(at: time), .ulpOfOne), nyquist.nextDown),
            gain: gain.value(at: time),
            q: max(q.value(at: time), .ulpOfOne),
            sampleRate: sampleRate
        )
        self.coefficients = coefficients
        samplesToUpdate = Self.updateInterval - 1

        return coefficients
    }

    // MARK: - Private
}

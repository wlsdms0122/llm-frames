//
//  BiquadFilterTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import Frames
@testable import FramesAVFoundation
import Testing

@Suite("BiquadFilter Tests")
struct BiquadFilterTests {
    // MARK: - Property
    private static let sampleRate = 48_000.0
    // Whole numbers of hertz, so a second holds whole cycles of each.
    private static let probes: [Double] = [50, 300, 1000, 3000, 12_000]

    // MARK: - Initializer
    // MARK: - Test
    @Test("each band type's magnitude response is the RBJ Audio EQ Cookbook's", arguments: MixBandType.allCases, [0.7071, 3])
    func followsCookbookMagnitude(
        type: MixBandType,
        q: Double
    ) {
        for probe in Self.probes {
            // Given
            var sut = BiquadFilter(
                band: MixBand(
                    type: type,
                    frequency: .constant(1000),
                    gain: type.takesGain ? .constant(6) : nil,
                    q: .constant(q)
                ),
                sampleRate: Self.sampleRate
            )

            // When
            let (left, right) = amplitudes(through: &sut, frequency: probe)

            // Then
            let expected = cookbookMagnitude(type: type, frequency: 1000, gain: 6, q: q, at: probe)
            #expect(abs(left - expected) <= expected * 1e-4, "\(type) at \(probe) Hz: \(left) is not \(expected)")
            #expect(left == right)
        }
    }

    @Test("a frequency that moves is read from its envelope again every 32 samples")
    func followsMovingFrequency() {
        // Given
        // A sweep from 100 Hz to 10 kHz over a second, its points sampled in log space at 30 frames per second.
        let points = (0...30).map { frame in
            EnvelopePoint(time: Double(frame) / 30, value: 100 * pow(100, Double(frame) / 30))
        }
        var sut = BiquadFilter(
            band: MixBand(type: .lowPass, frequency: .envelope(points), gain: nil, q: .constant(0.7071)),
            sampleRate: Self.sampleRate
        )

        // When
        let coefficients = (0..<24_033).map { sut.coefficients(atSample: $0) }

        // Then
        let middle = coefficients[24_000]
        #expect(isClose(middle, lowPass(at: 1000)))
        #expect(coefficients[24_001...24_031].allSatisfy { $0 == middle })
        let fraction = (24_032 / Self.sampleRate - points[15].time) / (points[16].time - points[15].time)
        #expect(isClose(coefficients[24_032], lowPass(at: points[15].value + (points[16].value - points[15].value) * fraction)))
    }

    // MARK: - Private
    // The steady amplitude of each channel's output for a sine of amplitude 1 at `frequency`, over one second after
    // half a second to settle.
    private func amplitudes(
        through filter: inout BiquadFilter,
        frequency: Double
    ) -> (Double, Double) {
        let settle = Int(Self.sampleRate / 2)
        let length = Int(Self.sampleRate)
        let omega = 2 * Double.pi * frequency / Self.sampleRate
        var sine = (left: 0.0, right: 0.0)
        var cosine = (left: 0.0, right: 0.0)
        for sample in 0..<settle + length {
            let input = sin(omega * Double(sample))
            let output = filter.process(StereoSample(left: input, right: input), atSample: sample)
            guard sample >= settle else { continue }
            sine.left += output.left * sin(omega * Double(sample))
            sine.right += output.right * sin(omega * Double(sample))
            cosine.left += output.left * cos(omega * Double(sample))
            cosine.right += output.right * cos(omega * Double(sample))
        }
        let scale = 2 / Double(length)

        return (
            scale * (sine.left * sine.left + cosine.left * cosine.left).squareRoot(),
            scale * (sine.right * sine.right + cosine.right * cosine.right).squareRoot()
        )
    }

    // |H(e^jw)| of the cookbook's b0 to a2 for a band, written out from its table.
    private func cookbookMagnitude(
        type: MixBandType,
        frequency: Double,
        gain: Double,
        q: Double,
        at probe: Double
    ) -> Double {
        let w = 2 * Double.pi * frequency / Self.sampleRate
        let a = pow(10, gain / 40)
        let alpha = sin(w) / (2 * q)
        let root = 2 * a.squareRoot() * alpha
        let c = cos(w)
        let (b0, b1, b2, a0, a1, a2): (Double, Double, Double, Double, Double, Double) = switch type {
        case .lowPass:
            ((1 - c) / 2, 1 - c, (1 - c) / 2, 1 + alpha, -2 * c, 1 - alpha)

        case .highPass:
            ((1 + c) / 2, -(1 + c), (1 + c) / 2, 1 + alpha, -2 * c, 1 - alpha)

        case .peak:
            (1 + alpha * a, -2 * c, 1 - alpha * a, 1 + alpha / a, -2 * c, 1 - alpha / a)

        case .lowShelf:
            (
                a * ((a + 1) - (a - 1) * c + root),
                2 * a * ((a - 1) - (a + 1) * c),
                a * ((a + 1) - (a - 1) * c - root),
                (a + 1) + (a - 1) * c + root,
                -2 * ((a - 1) + (a + 1) * c),
                (a + 1) + (a - 1) * c - root
            )

        case .highShelf:
            (
                a * ((a + 1) + (a - 1) * c + root),
                -2 * a * ((a - 1) + (a + 1) * c),
                a * ((a + 1) + (a - 1) * c - root),
                (a + 1) - (a - 1) * c + root,
                2 * ((a - 1) - (a + 1) * c),
                (a + 1) - (a - 1) * c - root
            )
        }
        let v = 2 * Double.pi * probe / Self.sampleRate
        let numerator = hypot(b0 + b1 * cos(v) + b2 * cos(2 * v), b1 * sin(v) + b2 * sin(2 * v))
        let denominator = hypot(a0 + a1 * cos(v) + a2 * cos(2 * v), a1 * sin(v) + a2 * sin(2 * v))

        return numerator / denominator
    }

    private func lowPass(at frequency: Double) -> BiquadCoefficients {
        BiquadCoefficients(type: .lowPass, frequency: frequency, gain: 0, q: 0.7071, sampleRate: Self.sampleRate)
    }

    private func isClose(
        _ coefficients: BiquadCoefficients,
        _ other: BiquadCoefficients
    ) -> Bool {
        let pairs = [
            (coefficients.b0, other.b0),
            (coefficients.b1, other.b1),
            (coefficients.b2, other.b2),
            (coefficients.a1, other.a1),
            (coefficients.a2, other.a2)
        ]

        return pairs.allSatisfy { abs($0 - $1) <= 1e-12 }
    }
}

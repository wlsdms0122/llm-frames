//
//  CrossfadeCurveTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

@testable import Frames
import Foundation
import Testing

@Suite("CrossfadeCurve Tests")
struct CrossfadeCurveTests {
    // MARK: - Property
    // A curve, a progress, and the outgoing and incoming gains it gives there.
    private static let gains: [(CrossfadeCurve, Double, Double, Double)] = [
        (.constantPower, 0, 1, 0),
        (.constantPower, 0.5, sqrt(0.5), sqrt(0.5)),
        (.constantPower, 1, 0, 1),
        (.constantGain, 0, 1, 0),
        (.constantGain, 0.5, 0.5, 0.5),
        (.constantGain, 1, 0, 1)
    ]

    private let tolerance = 1e-12

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "constant power gives cos(uπ/2) and sin(uπ/2), constant gain 1 - u and u, at the start, middle and end",
        arguments: gains
    )
    func givesGains(
        sut: CrossfadeCurve,
        progress: Double,
        outgoing: Double,
        incoming: Double
    ) {
        // Given
        // When
        let gains = sut.gains(at: progress)

        // Then
        #expect(abs(gains.outgoing - outgoing) < tolerance)
        #expect(abs(gains.incoming - incoming) < tolerance)
    }

    @Test("constant power keeps the sum of the two powers at 1 and constant gain the sum of the two gains at 1")
    func keepsItsSum() {
        // Given
        let progresses = stride(from: 0.0, through: 1, by: 0.125)

        // When
        let power = progresses.map { CrossfadeCurve.constantPower.gains(at: $0) }
        let gain = progresses.map { CrossfadeCurve.constantGain.gains(at: $0) }

        // Then
        #expect(power.allSatisfy { abs($0.outgoing * $0.outgoing + $0.incoming * $0.incoming - 1) < tolerance })
        #expect(gain.allSatisfy { abs($0.outgoing + $0.incoming - 1) < tolerance })
    }
}

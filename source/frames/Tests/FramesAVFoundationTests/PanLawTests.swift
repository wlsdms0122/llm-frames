//
//  PanLawTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/18/26.
//

import Foundation
import Frames
@testable import FramesAVFoundation
import Testing

@Suite("PanLaw Tests")
struct PanLawTests {
    // MARK: - Property
    // A pan and the left and right gains a mono sound takes there.
    private static let monoGains: [(Float, Float, Float)] = [
        (-1, 1, 0),
        (0, Float(sqrt(0.5)), Float(sqrt(0.5))),
        (1, 0, 1)
    ]

    // A pan and the left and right gains a stereo sound takes there.
    private static let stereoGains: [(Float, Float, Float)] = [
        (0, 1, 1),
        (1, 0, 1),
        (-0.5, 1, 0.5)
    ]

    private let tolerance: Float = 1e-6

    // MARK: - Initializer
    // MARK: - Test
    @Test("a mono sound takes the equal-power law, both channels at cos(π/4) at the centre", arguments: monoGains)
    func pansMonoAtEqualPower(
        pan: Float,
        left: Float,
        right: Float
    ) {
        // Given
        let sut = PanLaw(layout: ChannelLayout(labels: [.mono]))

        // When
        let gains = sut.gains(at: pan)

        // Then
        #expect(abs(gains.left - left) < tolerance)
        #expect(abs(gains.right - right) < tolerance)
    }

    @Test("a stereo sound takes a balance, untouched at the centre and lowering the other side", arguments: stereoGains)
    func balancesStereo(
        pan: Float,
        left: Float,
        right: Float
    ) {
        // Given
        let sut = PanLaw(layout: ChannelLayout(labels: [.left, .right]))

        // When
        let gains = sut.gains(at: pan)

        // Then
        #expect(gains == StereoGain(left: left, right: right))
    }

    @Test("a mono sound keeps its power at every pan")
    func keepsMonoPower() {
        // Given
        let sut = PanLaw(layout: ChannelLayout(labels: [.mono]))

        // When
        let gains = stride(from: Float(-1), through: 1, by: 0.25).map(sut.gains(at:))

        // Then
        #expect(gains.allSatisfy { abs($0.left * $0.left + $0.right * $0.right - 1) < tolerance })
    }
}

//
//  TimedValueTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("TimedValue Tests")
struct TimedValueTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a ratio leaf moves geometrically, so a sweep from 100 Hz to 10 kHz is at 1 kHz halfway")
    func samplesRatioInLogSpace() throws {
        // Given
        let sut = TimedValue.track([Keyframe(at: 0, value: .number(100)), Keyframe(at: 2, value: .number(10000))])

        // When
        let middle = try #require(sut.sampled(at: 1, as: .leaf(.ratio)).number)
        let quarter = try #require(sut.sampled(at: 0.5, as: .leaf(.ratio)).number)

        // Then
        #expect(abs(middle - 1000) < 1e-9)
        #expect(abs(quarter - 100 * pow(10, 0.5)) < 1e-9)
    }

    @Test("a ratio leaf under an overshooting ease stays above 0 where a straight line would cross it")
    func keepsRatioAboveZeroUnderOvershoot() throws {
        // Given
        let keyframes = [Keyframe(at: 0, value: LeafValue.number(10000), ease: .backOut), Keyframe(at: 1, value: .number(100))]
        let sut = TimedValue.track(keyframes)
        let fractions = (1..<100).map { Double($0) / 100 }
        let peak = try #require(fractions.max { Ease.backOut.value(at: $0) < Ease.backOut.value(at: $1) })

        // When
        let geometric = try #require(sut.sampled(at: peak, as: .leaf(.ratio)).number)
        let linear = try #require(sut.sampled(at: peak, as: .leaf(.number())).number)

        // Then
        let progress = Ease.backOut.value(at: peak)
        #expect(progress > 1)
        #expect(abs(geometric - 10000 * pow(100.0 / 10000, progress)) < 1e-6)
        #expect(geometric > 0 && geometric < 100)
        #expect(linear < 0)
    }

    @Test("a list of ratio tracks samples each element geometrically")
    func samplesRatioElementsInLogSpace() throws {
        // Given
        let element = TimedValue.track([Keyframe(at: 0, value: .number(1)), Keyframe(at: 1, value: .number(100))])
        let sut = TimedValue.list([element, element])

        // When
        let sampled = sut.sampled(at: 0.5, as: .leaf(LeafKind(form: .numbers(count: 2), interpolation: .geometric)))

        // Then
        let numbers = try #require(sampled.numbers)
        #expect(numbers.allSatisfy { abs($0 - 10) < 1e-9 })
    }
}

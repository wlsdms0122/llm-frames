//
//  SpanEvaluatorTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("SpanEvaluator Tests")
struct SpanEvaluatorTests {
    // MARK: - Property
    private let sut = SpanEvaluator()
    private let keys = [
        SpanKey(t: 0, values: [.scale: 0.6, .opacity: 0]),
        SpanKey(t: 0.3, values: [.opacity: 1]),
        SpanKey(t: 1, values: [.scale: 1])
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("each property joins only the keys that name it, in straight lines")
    func joinsOwnKeys() {
        // Given
        let span = Span(ease: .linear, keys: keys)

        // When
        let early = sut.motion(of: span, at: 0.15)
        let late = sut.motion(of: span, at: 0.5)

        // Then
        #expect(abs(early.value(of: .opacity) - 0.5) < 1e-9)
        #expect(abs(early.value(of: .scale) - 0.66) < 1e-9)
        #expect(late.value(of: .opacity) == 1)
        #expect(abs(late.value(of: .scale) - 0.8) < 1e-9)
    }

    @Test("a property the span does not name takes its default")
    func usesDefaults() {
        // Given
        let span = Span(ease: .linear, keys: keys)

        // When
        let motion = sut.motion(of: span, at: 0.5)

        // Then
        #expect(motion.value(of: .x) == 0)
        #expect(motion.value(of: .y) == 0)
        #expect(motion.value(of: .rotation) == 0)
        #expect(motion.value(of: .reveal) == 1)
        #expect(sut.motion(of: Span(ease: .linear, keys: []), at: 0.5).value(of: .scale) == 1)
    }

    @Test("the ease bends progress first, and the bent value drives every property")
    func bendsProgressFirst() {
        // Given
        let span = Span(ease: .easeIn, keys: keys)

        // When
        let motion = sut.motion(of: span, at: 0.5)

        // Then
        #expect(abs(motion.value(of: .opacity) - 0.125 / 0.3) < 1e-9)
        #expect(abs(motion.value(of: .scale) - (0.6 + 0.4 * 0.125)) < 1e-9)
    }

    @Test("an ease that overshoots carries a line that reaches 1 past its end, and holds one that ended earlier")
    func carriesOvershoot() {
        // Given
        let span = Span(ease: .backOut, keys: keys)

        // When
        let motion = sut.motion(of: span, at: 0.5)

        // Then
        #expect(abs(motion.value(of: .scale) - (0.6 + 0.4 * 1.0876975)) < 1e-6)
        #expect(motion.value(of: .opacity) == 1)
    }

    @Test("an opacity a spring carries past 1 or below 0 is drawn from 0 to 1, and an unranged property overshoots")
    func clampsOvershootingOpacity() {
        // Given
        let rising = Span(ease: .spring(bounce: 0.6), keys: [
            SpanKey(t: 0, values: [.opacity: 0, .scale: 0]),
            SpanKey(t: 1, values: [.opacity: 1, .scale: 1])
        ])
        let falling = Span(ease: .spring(bounce: 0.6), keys: [
            SpanKey(t: 0, values: [.opacity: 1]),
            SpanKey(t: 1, values: [.opacity: 0])
        ])

        // When
        let risen = sut.motion(of: rising, at: 0.6)
        let fallen = sut.motion(of: falling, at: 0.6)

        // Then
        #expect(risen.value(of: .scale) > 1)
        #expect(risen.value(of: .opacity) == 1)
        #expect(fallen.value(of: .opacity) == 0)
    }

    @Test("two keys at one progress cut from one value to the next")
    func cutsAtSharedProgress() {
        // Given
        let span = Span(ease: .linear, keys: [
            SpanKey(t: 0, values: [.opacity: 0]),
            SpanKey(t: 0.5, values: [.opacity: 0]),
            SpanKey(t: 0.5, values: [.opacity: 1]),
            SpanKey(t: 1, values: [.opacity: 1])
        ])

        // When
        let before = sut.motion(of: span, at: 0.49)
        let after = sut.motion(of: span, at: 0.5)

        // Then
        #expect(before.value(of: .opacity) == 0)
        #expect(after.value(of: .opacity) == 1)
    }

    @Test("progress outside the span holds its ends")
    func holdsOutsideSpan() {
        // Given
        let span = Span(ease: .linear, keys: keys)

        // When
        let before = sut.motion(of: span, at: -1)
        let after = sut.motion(of: span, at: 2)

        // Then
        #expect(before.value(of: .scale) == 0.6)
        #expect(after.value(of: .scale) == 1)
    }
}

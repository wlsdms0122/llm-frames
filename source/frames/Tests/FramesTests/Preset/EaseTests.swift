//
//  EaseTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("Ease Tests")
struct EaseTests {
    // MARK: - Property
    // The bounce above which a spring's first peak falls inside its span.
    private static let overshootingBounce: Double = 1 - 3.0.squareRoot() / 2
    private static let springPeaks: [(bounce: Double, overshoots: Bool)] = [
        (-0.5, false),
        (0, false),
        (overshootingBounce - 0.001, false),
        (overshootingBounce + 0.05, true),
        (0.6, true)
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "every ease of the table gives its formula",
        arguments: [
            (Ease.linear, 0.3, 0.3),
            (Ease.easeIn, 0.5, 0.125),
            (Ease.easeOut, 0.5, 0.875),
            (Ease.easeInOut, 0.25, 0.0625),
            (Ease.easeInOut, 0.75, 0.9375),
            (Ease.backOut, 0.5, 1.0876975),
            (Ease.bounceOut, 0.2, 0.3025),
            (Ease.bounceOut, 0.5, 0.765625),
            (Ease.bounceOut, 0.8, 0.94),
            (Ease.bounceOut, 0.95, 0.98453125),
            (Ease.step, 0.99, 0),
            (Ease.step, 1, 1),
            (Ease.cubicBezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1), 0.5, 0.8024033877),
            (Ease.cubicBezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1), 0.5, 0.5),
            (Ease.cubicBezier(x1: 0, y1: 0, x2: 1, y2: 1), 0.3, 0.3),
            (Ease.spring(bounce: 0), 0.5, 0.8323462377),
            (Ease.spring(bounce: 0.3), 0.5, 0.9700236787),
            (Ease.spring(bounce: 0.5), 0.25, 0.6539837125),
            (Ease.spring(bounce: -0.5), 0.5, 0.6697212282)
        ]
    )
    func followsFormula(
        sut: Ease,
        progress: Double,
        expected: Double
    ) {
        // Given, When
        let value = sut.value(at: progress)

        // Then
        #expect(abs(value - expected) < 1e-6, "\(sut) at \(progress) gave \(value)")
    }

    @Test(
        "every ease gives exactly 0 at the start of its span and exactly 1 at its end",
        arguments: [
            Ease.linear, .easeIn, .easeOut, .easeInOut, .backOut, .bounceOut, .step,
            .cubicBezier(x1: 0.68, y1: -0.55, x2: 0.27, y2: 1.55), .spring(bounce: 0.5)
        ]
    )
    func keepsEnds(sut: Ease) {
        // Given, When
        let start = sut.value(at: 0)
        let end = sut.value(at: 1)

        // Then
        #expect(start == 0)
        #expect(end == 1)
    }

    @Test(
        "a spring is normalised to start at exactly 0 and land on exactly 1",
        arguments: [-0.999, -0.5, 0, 0.3, 0.9, 0.999]
    )
    func landsSpring(bounce: Double) {
        // Given
        let sut = Ease.spring(bounce: bounce)

        // When
        let start = sut.value(at: 0)
        let end = sut.value(at: 1)

        // Then
        #expect(start == 0)
        #expect(end == 1)
    }

    @Test("a spring passes 1 only with a bounce above 1 - √3/2", arguments: springPeaks)
    func overshootsAboveThreshold(
        bounce: Double,
        overshoots: Bool
    ) {
        // Given
        let sut = Ease.spring(bounce: bounce)

        // When
        let peak = (0...2000).map { sut.value(at: Double($0) / 2000) }.max() ?? 0

        // Then
        #expect((peak > 1 + 1e-12) == overshoots, "bounce \(bounce) peaked at \(peak)")
    }

    @Test(
        "an ease's range over a span of progress is its extremes there, overshoots included",
        arguments: [
            Ease.linear, .easeIn, .easeOut, .easeInOut, .backOut, .bounceOut, .step,
            .cubicBezier(x1: 0.3, y1: -0.6, x2: 0.7, y2: 1.6), .cubicBezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1),
            .spring(bounce: -0.5), .spring(bounce: 0), .spring(bounce: 0.3), .spring(bounce: 0.7)
        ]
    )
    func givesRange(sut: Ease) {
        for (start, end) in [(0.0, 1.0), (0.1, 0.5), (0.5, 0.9), (0.4, 0.4)] {
            // When
            let range = sut.range(from: start, to: end)

            // Then
            let sampled = (0...4000).map { sut.value(at: start + (end - start) * Double($0) / 4000) }
            let low = sampled.min() ?? 0
            let high = sampled.max() ?? 0
            #expect(range.lowerBound <= low + 1e-12 && range.lowerBound > low - 1e-2, "\(sut) from \(start) to \(end)")
            #expect(range.upperBound >= high - 1e-12 && range.upperBound < high + 1e-2, "\(sut) from \(start) to \(end)")
        }
    }

    @Test("an ease is read from its name or from four numbers")
    func readsFromJSON() {
        // Given
        let names = ["linear", "ease-in", "ease-out", "ease-in-out", "back-out", "bounce-out", "step"]

        // When
        let eases = names.map { Ease(value: .string($0)) }
        let bezier = Ease(value: .array([.number(0.1), .number(0.2), .number(0.3), .number(0.4)]))

        // Then
        #expect(eases == [.linear, .easeIn, .easeOut, .easeInOut, .backOut, .bounceOut, .step])
        #expect(bezier == .cubicBezier(x1: 0.1, y1: 0.2, x2: 0.3, y2: 0.4))
        #expect(Ease(value: .string("ease")) == nil)
    }

    @Test("a spring is read from its bounce, which lies between -1 and 1 and is the spring's only key")
    func readsSpring() throws {
        // Given
        let spring = try Fixture.json(#"{ "spring": { "bounce": 0.4 } }"#)
        let refused = try [
            #"{ "spring": { "bounce": 1 } }"#,
            #"{ "spring": { "bounce": -1 } }"#,
            #"{ "spring": { "bounce": 0.2, "mass": 1 } }"#,
            #"{ "spring": { } }"#,
            #"{ "spring": { "bounce": 0.2 }, "ease": "linear" }"#
        ].map(Fixture.json)

        // When
        let sut = Ease(value: spring)

        // Then
        #expect(sut == .spring(bounce: 0.4))
        #expect(refused.allSatisfy { Ease(value: $0) == nil })
    }
}

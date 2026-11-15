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
            (Ease.cubicBezier(x1: 0, y1: 0, x2: 1, y2: 1), 0.3, 0.3)
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
        "every ease starts at 0 and ends at 1",
        arguments: [
            Ease.linear, .easeIn, .easeOut, .easeInOut, .backOut, .bounceOut, .step,
            .cubicBezier(x1: 0.68, y1: -0.55, x2: 0.27, y2: 1.55)
        ]
    )
    func keepsEnds(sut: Ease) {
        // Given, When
        let start = sut.value(at: 0)
        let end = sut.value(at: 1)

        // Then
        #expect(abs(start) < 1e-9)
        #expect(abs(end - 1) < 1e-9)
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
}

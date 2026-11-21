//
//  ToneCurveTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

@testable import Frames
import Testing

@Suite("ToneCurve Tests")
struct ToneCurveTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a parametric curve's result is clipped to 0 to 1, as ICC.1 gives it",
        arguments: [
            // Type 2, Y = (aX + b)^g + c, with c lifting the top above 1 and with c below 0 at black.
            (ToneCurve.parametric(functionType: 2, parameters: [1, 1, 0, 0.5]), 1.0, 1.0),
            (ToneCurve.parametric(functionType: 2, parameters: [1, 1, 0, -0.2]), 0.0, 0.0),
            // Type 4, Y = (aX + b)^g + e above d and cX + f below it, with e lifting the top and f below 0 at black.
            (ToneCurve.parametric(functionType: 4, parameters: [1, 1, 0, 1, 0.1, 0.3, -0.1]), 1.0, 1.0),
            (ToneCurve.parametric(functionType: 4, parameters: [1, 1, 0, 1, 0.1, 0.3, -0.1]), 0.0, 0.0),
            // Inside the range the result is the formula's.
            (ToneCurve.parametric(functionType: 2, parameters: [1, 1, 0, 0.5]), 0.25, 0.75)
        ]
    )
    func clipsResult(
        curve: ToneCurve,
        encoded: Double,
        expected: Double
    ) {
        // Given
        let sut = curve

        // When
        let linear = sut.linear(encoded)

        // Then
        #expect(abs(linear - expected) < 1e-12)
    }

    // MARK: - Private
}

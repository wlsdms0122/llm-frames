//
//  BiquadState.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/19/26.
//

// One channel's past samples of a biquad in direct form I, all 0 at rest. Direct form I keeps the past input and
// output themselves, which stay the filter's own when its coefficients change while a value moves.
struct BiquadState: Sendable {
    // MARK: - Property
    private var input1: Double = 0
    private var input2: Double = 0
    private var output1: Double = 0
    private var output2: Double = 0

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    mutating func filter(
        _ input: Double,
        by coefficients: BiquadCoefficients
    ) -> Double {
        let output = coefficients.b0 * input + coefficients.b1 * input1 + coefficients.b2 * input2
            - coefficients.a1 * output1 - coefficients.a2 * output2
        input2 = input1
        input1 = input
        output2 = output1
        output1 = output

        return output
    }

    // MARK: - Private
}

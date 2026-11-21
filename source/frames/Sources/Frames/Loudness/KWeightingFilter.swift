//
//  KWeightingFilter.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The K-weighting of ITU-R BS.1770-5 at 48 kHz on one channel: the shelf that models the head, then the high-pass, each
// the biquad y[n] = b0 x[n] + b1 x[n-1] + b2 x[n-2] - a1 y[n-1] - a2 y[n-2], at rest with its past samples 0.
struct KWeightingFilter: Sendable {
    // MARK: - Property
    private var shelfInput: (Double, Double) = (0, 0)
    private var shelfOutput: (Double, Double) = (0, 0)
    private var passInput: (Double, Double) = (0, 0)
    private var passOutput: (Double, Double) = (0, 0)

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    mutating func process(_ input: Double) -> Double {
        let shelf = 1.53512485958697 * input - 2.69169618940638 * shelfInput.0 + 1.19839281085285 * shelfInput.1
            + 1.69065929318241 * shelfOutput.0 - 0.73248077421585 * shelfOutput.1
        shelfInput = (input, shelfInput.0)
        shelfOutput = (shelf, shelfOutput.0)

        let pass = shelf - 2 * passInput.0 + passInput.1 + 1.99004745483398 * passOutput.0 - 0.99007225036621 * passOutput.1
        passInput = (shelf, passInput.0)
        passOutput = (pass, passOutput.0)

        return pass
    }

    // MARK: - Private
}

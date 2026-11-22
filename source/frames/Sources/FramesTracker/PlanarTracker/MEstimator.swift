//
//  MEstimator.swift
//  FramesTracker
//
//  Created by JSilver on 11/22/26.
//

// The robust weights of iteratively reweighted least squares, each a residual's weight for a residual scale, with
// the tuning constants of 95 % efficiency under Gaussian noise. Huber's weight never reaches 0, so it converges from a
// guess far off; Tukey's biweight is 0 past its constant, so the pixels it gives 0 are the outliers.
enum MEstimator: Sendable {
    case huber
    case tukey

    // MARK: - Property
    private var tuningConstant: Double {
        switch self {
        case .huber:
            1.345

        case .tukey:
            4.685
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    func weight(
        of residual: Double,
        scale: Double
    ) -> Double {
        let bound = tuningConstant * scale
        switch self {
        case .huber:
            return abs(residual) <= bound ? 1 : bound / abs(residual)

        case .tukey:
            let ratio = residual / bound
            return abs(ratio) < 1 ? (1 - ratio * ratio) * (1 - ratio * ratio) : 0
        }
    }

    // MARK: - Private
}

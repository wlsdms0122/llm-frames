//
//  ToneCurve.swift
//  Frames
//
//  Created by JSilver on 11/20/26.
//

import Foundation

// The tone curve of one channel of an ICC profile (ICC.1), from the channel's encoded value to its linear value, both
// from 0 to 1: a gamma, a parametric curve, or a table interpolated linearly. An encoded value is clipped to 0 to 1, the
// curve's domain, and the result to 0 to 1, as ICC.1 gives it.
package enum ToneCurve: Equatable, Sendable {
    // Y = X^gamma, a `curv` of one entry.
    case gamma(Double)
    // A `para` curve of function type 0 to 4 with its parameters in the order ICC.1 writes them: g, a, b, c, d, e, f.
    case parametric(functionType: Int, parameters: [Double])
    // A `curv` of two or more entries, spread evenly over 0 to 1. A `curv` of none is the identity, `gamma(1)`.
    case table([Double])

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    package func linear(_ encoded: Double) -> Double {
        min(max(unclipped(min(max(encoded, 0), 1)), 0), 1)
    }

    // MARK: - Private
    private func unclipped(_ x: Double) -> Double {
        switch self {
        case let .gamma(gamma):
            return pow(x, gamma)

        case let .parametric(functionType, parameters):
            return parametric(x, functionType: functionType, parameters: parameters)

        case let .table(entries):
            guard entries.count > 1 else { return entries.first ?? x }

            let position = x * Double(entries.count - 1)
            let lower = min(Int(position), entries.count - 2)
            let fraction = position - Double(lower)

            return entries[lower] + (entries[lower + 1] - entries[lower]) * fraction
        }
    }

    // A parameter the function type does not take is 0.
    private func parametric(
        _ x: Double,
        functionType: Int,
        parameters: [Double]
    ) -> Double {
        let value = { (index: Int) in parameters.indices.contains(index) ? parameters[index] : 0 }
        let (g, a, b, c, d, e, f) = (value(0), value(1), value(2), value(3), value(4), value(5), value(6))
        let power = { (base: Double) in base > 0 ? pow(base, g) : 0 }

        switch functionType {
        case 1:
            return x >= -b / a ? power(a * x + b) : 0

        case 2:
            return x >= -b / a ? power(a * x + b) + c : c

        case 3:
            return x >= d ? power(a * x + b) : c * x

        case 4:
            return x >= d ? power(a * x + b) + e : c * x + f

        default:
            return power(x)
        }
    }
}

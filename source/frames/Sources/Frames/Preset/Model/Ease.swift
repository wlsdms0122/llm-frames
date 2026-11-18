//
//  Ease.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

enum Ease: Equatable, Sendable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case backOut
    case bounceOut
    case step
    case cubicBezier(x1: Double, y1: Double, x2: Double, y2: Double)
    // A damped spring settling from 0 to 1, `bounce` greater than -1 and less than 1.
    case spring(bounce: Double)

    // MARK: - Property
    // MARK: - Initializer
    init?(value: JSONValue) {
        switch value {
        case .string("linear"):
            self = .linear

        case .string("ease-in"):
            self = .easeIn

        case .string("ease-out"):
            self = .easeOut

        case .string("ease-in-out"):
            self = .easeInOut

        case .string("back-out"):
            self = .backOut

        case .string("bounce-out"):
            self = .bounceOut

        case .string("step"):
            self = .step

        case let .array(elements):
            let numbers = elements.compactMap(\.numberValue)
            guard numbers.count == 4, elements.count == 4 else { return nil }

            self = .cubicBezier(x1: numbers[0], y1: numbers[1], x2: numbers[2], y2: numbers[3])

        case let .object(object):
            guard object.keys == ["spring"], let spring = object["spring"]?.objectValue, spring.keys == ["bounce"],
                  let bounce = spring["bounce"]?.numberValue, bounce > -1, bounce < 1 else { return nil }

            self = .spring(bounce: bounce)

        default:
            return nil
        }
    }

    // MARK: - Public
    func value(at progress: Double) -> Double {
        let u = progress

        switch self {
        case .linear:
            return u

        case .easeIn:
            return u * u * u

        case .easeOut:
            return 1 - pow(1 - u, 3)

        case .easeInOut:
            return u < 0.5 ? 4 * u * u * u : 1 - pow(2 - 2 * u, 3) / 2

        case .backOut:
            return 1 + 2.70158 * pow(u - 1, 3) + 1.70158 * pow(u - 1, 2)

        case .bounceOut:
            return bounceOut(u)

        case .step:
            return u < 1 ? 0 : 1

        case let .cubicBezier(x1, y1, x2, y2):
            return cubicBezier(u, x1: x1, y1: y1, x2: x2, y2: y2)

        case let .spring(bounce):
            return springResponse(at: u, bounce: bounce) / springResponse(at: 1, bounce: bounce)
        }
    }

    // MARK: - Private
    private func bounceOut(_ u: Double) -> Double {
        let n = 7.5625
        let d = 2.75

        if u < 1 / d {
            return n * u * u
        } else if u < 2 / d {
            let shifted = u - 1.5 / d
            return n * shifted * shifted + 0.75
        } else if u < 2.5 / d {
            let shifted = u - 2.25 / d
            return n * shifted * shifted + 0.9375
        } else {
            let shifted = u - 2.625 / d
            return n * shifted * shifted + 0.984375
        }
    }

    // The step response of a damped harmonic oscillator at rest at 0 and pulled toward 1, its natural frequency one
    // cycle over the span, so it depends on u and the bounce alone.
    private func springResponse(
        at u: Double,
        bounce: Double
    ) -> Double {
        let theta = 2 * Double.pi * u

        if bounce > 0 {
            let damping = 1 - bounce
            let damped = (1 - damping * damping).squareRoot()
            return 1 - exp(-damping * theta) * (cos(damped * theta) + damping / damped * sin(damped * theta))
        }
        guard bounce < 0 else { return 1 - exp(-theta) * (1 + theta) }

        // The hyperbolic form multiplies a vanishing exponential by a growing one, so the over-damped response is
        // written by its two real roots, the slow one from their product of 1 to keep its digits.
        let damping = 1 / (1 + bounce)
        let fast = -damping - (damping * damping - 1).squareRoot()
        let slow = 1 / fast
        return 1 - (fast * exp(slow * theta) - slow * exp(fast * theta)) / (fast - slow)
    }

    private func cubicBezier(
        _ u: Double,
        x1: Double,
        y1: Double,
        x2: Double,
        y2: Double
    ) -> Double {
        guard u > 0 else { return 0 }
        guard u < 1 else { return 1 }

        let parameter = bezierParameter(forX: u, x1: x1, x2: x2)
        return bezier(parameter, y1, y2)
    }

    // x(s) rises monotonically because x1 and x2 lie in 0...1, so Newton's method with a bisection fallback finds s.
    private func bezierParameter(
        forX x: Double,
        x1: Double,
        x2: Double
    ) -> Double {
        var s = x
        for _ in 0..<8 {
            let error = bezier(s, x1, x2) - x
            guard abs(error) > 1e-12 else { return s }

            let slope = bezierSlope(s, x1, x2)
            guard abs(slope) > 1e-9 else { break }

            s -= error / slope
        }

        var low = 0.0
        var high = 1.0
        s = x
        for _ in 0..<64 {
            let value = bezier(s, x1, x2)
            guard abs(value - x) > 1e-12 else { return s }

            if value < x {
                low = s
            } else {
                high = s
            }
            s = (low + high) / 2
        }

        return s
    }

    private func bezier(
        _ s: Double,
        _ p1: Double,
        _ p2: Double
    ) -> Double {
        let inverse = 1 - s
        return 3 * inverse * inverse * s * p1 + 3 * inverse * s * s * p2 + s * s * s
    }

    private func bezierSlope(
        _ s: Double,
        _ p1: Double,
        _ p2: Double
    ) -> Double {
        let inverse = 1 - s
        return 3 * inverse * inverse * p1 + 6 * inverse * s * (p2 - p1) + 3 * s * s * (1 - p2)
    }
}

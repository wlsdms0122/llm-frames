//
//  LeafDomain.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The values a timed leaf may take. A static value, or a leaf one keyframe writes, is checked against `isSeen`; a leaf
// two keyframes or more write against `contains`, since such a keyframe is one end of a change. A sampled value is
// clamped to it.
enum LeafDomain: Equatable, Sendable {
    case any
    case nonNegative
    case positive
    case range(ClosedRange<Double>)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func contains(_ number: Double) -> Bool {
        switch self {
        case .any:
            true

        case .nonNegative, .positive:
            number >= 0

        case let .range(range):
            range.contains(number)
        }
    }

    func isSeen(_ number: Double) -> Bool {
        guard case .positive = self else { return contains(number) }

        return number > 0
    }

    func clamped(_ number: Double) -> Double {
        switch self {
        case .any:
            number

        case .nonNegative, .positive:
            max(number, 0)

        case let .range(range):
            min(max(number, range.lowerBound), range.upperBound)
        }
    }

    // MARK: - Private
}

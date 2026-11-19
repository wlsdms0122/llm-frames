//
//  LeafDomain.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The numbers a value may take, a timed leaf's or a key's the key tables declare. For a timed leaf, a static value, or
// a leaf one keyframe writes, is checked against the domain; a leaf two keyframes or more write against its `sampled`
// domain, since such a keyframe is one end of a change. A sampled value is clamped to the sampled domain.
enum LeafDomain: Equatable, Sendable {
    case any
    case nonNegative
    case positive
    case range(ClosedRange<Double>)
    // Greater than the first bound and less than the second, at every sample too: a value interpolated geometrically
    // has no 0.
    case between(Double, Double)

    // MARK: - Property
    // A positive length or size may be 0 where it is sampled.
    var sampled: LeafDomain {
        self == .positive ? .nonNegative : self
    }

    var description: String {
        switch self {
        case .any:
            "any number"

        case .nonNegative:
            "0 or more"

        case .positive:
            "above 0"

        case let .range(range) where range.upperBound == .infinity:
            "\(Self.written(range.lowerBound)) or more"

        case let .range(range) where range.lowerBound == -.infinity:
            "\(Self.written(range.upperBound)) or less"

        case let .range(range):
            "within \(Self.written(range.lowerBound)) to \(Self.written(range.upperBound))"

        case let .between(lower, upper) where upper == .infinity:
            "above \(Self.written(lower))"

        case let .between(lower, upper):
            "above \(Self.written(lower)) and below \(Self.written(upper))"
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    func contains(_ number: Double) -> Bool {
        switch self {
        case .any:
            true

        case .nonNegative:
            number >= 0

        case .positive:
            number > 0

        case let .range(range):
            range.contains(number)

        case let .between(lower, upper):
            lower < number && number < upper
        }
    }

    // The words every stop gives for a number outside the domain, the key check's and the look's alike.
    func refusal(of number: Double) -> String {
        "\(Self.written(number)) is not \(description)"
    }

    // Each number of a leaf's value as written, a list's at its index.
    func check(
        _ value: JSONValue,
        place: Place
    ) throws {
        if let number = value.numberValue {
            guard contains(number) else { throw LookError.outsideDomain(place: place, value: number, domain: self) }

            return
        }

        for (index, element) in (value.arrayValue ?? []).enumerated() {
            guard let number = element.numberValue, !contains(number) else { continue }

            throw LookError.outsideDomain(place: place.appending(index: index), value: number, domain: self)
        }
    }

    func clamped(_ number: Double) -> Double {
        switch self {
        case .any:
            number

        case .nonNegative, .positive:
            max(number, 0)

        case let .range(range):
            min(max(number, range.lowerBound), range.upperBound)

        case let .between(lower, upper):
            min(max(number, lower.nextUp), upper.nextDown)
        }
    }

    // MARK: - Private
    private static func written(_ number: Double) -> String {
        JSONValue.number(number).written
    }
}

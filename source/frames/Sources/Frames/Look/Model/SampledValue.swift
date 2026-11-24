//
//  SampledValue.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A timed value at one instant: each timed leaf sampled and clamped, each static leaf as it is.
indirect enum SampledValue: Equatable, Sendable {
    case off
    case fixed(JSONValue)
    case leaf(LeafValue)
    case object([String: SampledValue])
    case list([SampledValue])
    case form(String, SampledValue)

    // MARK: - Property
    var number: Double? {
        guard case let .leaf(.number(number)) = self else { return nil }

        return number
    }

    var numbers: [Double]? {
        guard case let .leaf(.numbers(numbers)) = self else { return nil }

        return numbers
    }

    // Corner radii, which resolve and the resolved reader give as four whatever form they were written in.
    var cornerRadii: CornerRadii? {
        numbers.flatMap(CornerRadii.init(values:))
    }

    var color: Color? {
        guard case let .leaf(.color(color)) = self else { return nil }

        return color
    }

    var name: String? {
        guard case let .fixed(value) = self else { return nil }

        return value.stringValue
    }

    // MARK: - Initializer
    // MARK: - Public
    subscript(key: String) -> SampledValue? {
        guard case let .object(members) = self else { return nil }

        return members[key]
    }

    // MARK: - Private
}

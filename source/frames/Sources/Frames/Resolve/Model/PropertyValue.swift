//
//  PropertyValue.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A keyframable property as written: a static value, or keyframes on the clip's clock. A property written both ways
// stopped at the key tables.
enum PropertyValue<Value: Equatable & Sendable>: Equatable, Sendable {
    case value(Value)
    case keyframes([TimedValue<Value>])

    // MARK: - Property
    // The earliest keyframe, the first written of those at one instant, and nil for a static value.
    var first: TimedValue<Value>? {
        switch self {
        case .value:
            nil

        case let .keyframes(keyframes):
            keyframes.min { $0.at < $1.at }
        }
    }

    // The value the property takes first: its static value, or its earliest keyframe's. A property read with keyframes
    // has at least one, so `first` is there.
    var firstValue: Value {
        switch self {
        case let .value(value):
            value

        case let .keyframes(keyframes):
            (first ?? keyframes[0]).value
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

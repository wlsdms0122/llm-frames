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

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

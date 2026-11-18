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
            Self.earliest(of: keyframes)
        }
    }

    // The value the property takes first: its static value, or its earliest keyframe's.
    var firstValue: Value {
        switch self {
        case let .value(value):
            value

        case let .keyframes(keyframes):
            Self.earliest(of: keyframes).value
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
    // A property is read with keyframes only where at least one keyframe writes it, so the list is never empty.
    private static func earliest(of keyframes: [TimedValue<Value>]) -> TimedValue<Value> {
        keyframes.dropFirst().reduce(keyframes[0]) { earliest, keyframe in
            keyframe.at < earliest.at ? keyframe : earliest
        }
    }
}

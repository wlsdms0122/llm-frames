//
//  PropertyValue+Map.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A property with each value changed in place, its keyframes keeping their instants and eases.
extension PropertyValue {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func map<Other: Equatable & Sendable>(_ transform: (Value) -> Other) -> PropertyValue<Other> {
        switch self {
        case let .value(value):
            .value(transform(value))

        case let .keyframes(keyframes):
            .keyframes(keyframes.map { keyframe in
                TimedValue(
                    index: keyframe.index,
                    at: keyframe.at,
                    value: transform(keyframe.value),
                    ease: keyframe.ease
                )
            })
        }
    }

    // MARK: - Private
}

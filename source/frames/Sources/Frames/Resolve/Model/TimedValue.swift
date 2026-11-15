//
//  TimedValue.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One keyframe's value of a property. `index` is the keyframe's place in the clip's `keyframes`, and `at` its instant
// on the clip's clock.
struct TimedValue<Value: Equatable & Sendable>: Equatable, Sendable {
    // MARK: - Property
    let index: Int
    let at: Double
    let value: Value
    let ease: Ease

    // MARK: - Initializer
    init(
        index: Int,
        at: Double,
        value: Value,
        ease: Ease
    ) {
        self.index = index
        self.at = at
        self.value = value
        self.ease = ease
    }

    // MARK: - Public
    func with<Other: Equatable & Sendable>(_ value: Other) -> TimedValue<Other> {
        TimedValue<Other>(index: index, at: at, value: value, ease: ease)
    }

    // MARK: - Private
}

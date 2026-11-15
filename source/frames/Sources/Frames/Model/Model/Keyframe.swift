//
//  Keyframe.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct Keyframe<Value: Interpolable>: Equatable, Sendable {
    // MARK: - Property
    let at: Double
    let value: Value
    let ease: Ease

    // MARK: - Initializer
    init(
        at: Double,
        value: Value,
        ease: Ease = .linear
    ) {
        self.at = at
        self.value = value
        self.ease = ease
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  Keyframe+Map.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

extension Keyframe {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func map<Other: Equatable & Sendable>(_ transform: (Value) -> Other) -> Keyframe<Other> {
        Keyframe<Other>(at: at, value: transform(value), ease: ease)
    }

    // MARK: - Private
}

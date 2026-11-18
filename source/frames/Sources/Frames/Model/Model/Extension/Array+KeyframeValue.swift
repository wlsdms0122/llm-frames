//
//  Array+KeyframeValue.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The value a resolved property's keyframes give at a time, as their `KeyframeTrack` interpolates it. Resolve leaves
// every property it keyframes with at least one keyframe, so there is always one.
extension Array {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func value<Value: Interpolable>(at time: Double) -> Value where Element == Keyframe<Value> {
        KeyframeTrack(keyframes: self).value(at: time) ?? self[0].value
    }

    // An ease that overshoots carries an opacity past its keyframes, and an opacity is drawn from 0 to 1.
    func opacity(at time: Double) -> Double where Element == Keyframe<Double> {
        Swift.min(Swift.max(value(at: time), 0), 1)
    }

    // MARK: - Private
}

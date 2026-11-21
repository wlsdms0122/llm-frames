//
//  Array+KeyframeValue.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The value a resolved property's keyframes give at a time, as their `KeyframeTrack` interpolates it, clamped to the
// side of their jumps that the time's `frameTime` is on (FRAMES-29). Resolve leaves every property it keyframes with at
// least one keyframe, so there is always one.
extension Array {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The value at a time outside a sample of a frame with motion blur, as resolve and the mix plan read it.
    func value<Value: Interpolable>(at time: Double) -> Value where Element == Keyframe<Value> {
        value(at: time, onSideOf: time)
    }

    func opacity(at time: Double) -> Double where Element == Keyframe<Double> {
        opacity(at: time, onSideOf: time)
    }

    func value<Value: Interpolable>(at time: SampleTime) -> Value where Element == Keyframe<Value> {
        value(at: time.instant, onSideOf: time.frameTime)
    }

    // An ease that overshoots carries an opacity past its keyframes, and an opacity is drawn from 0 to 1.
    func opacity(at time: SampleTime) -> Double where Element == Keyframe<Double> {
        opacity(at: time.instant, onSideOf: time.frameTime)
    }

    // The value at an instant clamped to T's side of the jumps between them, T being the frame's instant.
    func value<Value: Interpolable>(
        at time: Double,
        onSideOf frameTime: Double
    ) -> Value where Element == Keyframe<Value> {
        KeyframeTrack(keyframes: self).value(at: time, onSideOf: frameTime) ?? self[0].value
    }

    func opacity(
        at time: Double,
        onSideOf frameTime: Double
    ) -> Double where Element == Keyframe<Double> {
        Swift.min(Swift.max(value(at: time, onSideOf: frameTime), 0), 1)
    }

    // MARK: - Private
}

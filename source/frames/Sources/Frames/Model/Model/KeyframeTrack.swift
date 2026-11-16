//
//  KeyframeTrack.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The keyframes of one property, in time order.
struct KeyframeTrack<Value: Interpolable>: Equatable, Sendable {
    // MARK: - Property
    let keyframes: [Keyframe<Value>]

    // MARK: - Initializer
    init(keyframes: [Keyframe<Value>]) {
        self.keyframes = keyframes.enumerated()
            .sorted { left, right in
                left.element.at == right.element.at ? left.offset < right.offset : left.element.at < right.element.at
            }
            .map(\.element)
    }

    // MARK: - Public
    func value(at time: Double) -> Value? {
        guard let first = keyframes.first, let last = keyframes.last else { return nil }
        guard time >= first.at else { return first.value }
        guard time < last.at else { return last.value }

        // The span that holds the time starts at the last keyframe at or before it, so two keyframes at one instant cut.
        guard let index = keyframes.lastIndex(where: { $0.at <= time }) else { return first.value }

        let start = keyframes[index]
        let end = keyframes[index + 1]
        let fraction = (time - start.at) / (end.at - start.at)
        return Value.interpolate(from: start.value, to: end.value, progress: start.ease.value(at: fraction))
    }

    // MARK: - Private
}

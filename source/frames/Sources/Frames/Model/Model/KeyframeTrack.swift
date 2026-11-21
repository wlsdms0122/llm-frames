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

    // The value at an instant on T's side, T being the frame's instant: clamped to T's side of every jump between
    // them, and the limit from T's side at that jump (FRAMES-29). A jump is the end of a span eased by `step` and two
    // keyframes at one instant. T reads a jump's later side when it lies on it, so an instant before T is clamped to the
    // value at the jump, and one after T to the value just before it.
    func value(
        at time: Double,
        onSideOf frameTime: Double
    ) -> Value? {
        if time > frameTime, let jump = jumps.first(where: { frameTime < $0 && $0 <= time }) {
            return value(justBefore: jump)
        }
        if time < frameTime, let jump = jumps.last(where: { time < $0 && $0 <= frameTime }) {
            return value(at: jump)
        }

        return value(at: time)
    }

    // MARK: - Private
    // The instants the value jumps at, in time order: where a span eased by `step` ends, and where two keyframes meet.
    private var jumps: [Double] {
        zip(keyframes, keyframes.dropFirst())
            .filter { start, end in start.ease == .step || start.at == end.at }
            .map(\.1.at)
    }

    // The limit from before a jump: a `step` span's start value, or the keyframe the line that reaches it ends on.
    private func value(justBefore jump: Double) -> Value? {
        guard let index = keyframes.lastIndex(where: { $0.at < jump }) else { return keyframes.first?.value }

        return keyframes[index].ease == .step ? keyframes[index].value : keyframes[index + 1].value
    }
}

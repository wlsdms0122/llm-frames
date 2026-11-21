//
//  PropertyValue+Keyframes.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A keyframable property as the keyframe list the resolved document holds: keyframes in time order, those at one
// instant in the order they were written, each with the ease of the span that starts at it. A static value is one
// keyframe at the instant its areas take effect, which holds at every time. A value a track can carry is a
// `FollowedValue`, a static value true on the track's frame kept as that value.
extension PropertyValue {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // `value` turns each value found into the value the document holds.
    func keyframes<Other: Equatable & Sendable>(
        at instant: Double,
        _ value: (Value) -> Other
    ) -> [Keyframe<Other>] {
        switch self {
        case let .value(written):
            return [Keyframe(at: instant, value: value(written))]

        case let .keyframes(keyframes):
            return keyframes.enumerated()
                .sorted { left, right in
                    left.element.at == right.element.at ? left.offset < right.offset : left.element.at < right.element.at
                }
                .map { Keyframe(at: $0.element.at, value: value($0.element.value), ease: $0.element.ease) }
        }
    }

    func followed<Other: Equatable & Sendable>(
        at instant: Double,
        isOnTrackFrame: Bool,
        _ value: (Value) -> Other
    ) -> FollowedValue<Other> {
        if isOnTrackFrame, case let .value(written) = self {
            return .onTrackFrame(value(written))
        }

        return .keyframes(keyframes(at: instant, value))
    }

    // MARK: - Private
}

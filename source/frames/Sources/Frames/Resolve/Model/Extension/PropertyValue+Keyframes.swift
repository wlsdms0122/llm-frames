//
//  PropertyValue+Keyframes.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A keyframable property as the keyframe list the resolved document holds: keyframes in time order, those at one
// instant in the order they were written, each with the ease of the span that starts at it. A static value is one
// keyframe at the instant its areas take effect, which holds at every time.
extension PropertyValue {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // `value` turns each value found into the value the document holds.
    func keyframes<Other: Interpolable>(
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

    // MARK: - Private
}

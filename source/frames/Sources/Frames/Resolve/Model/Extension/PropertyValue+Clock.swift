//
//  PropertyValue+Clock.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A property written on a clip's clock with its keyframes moved to sequence time. A static value holds at every time.
extension PropertyValue {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func inSequenceTime(on clock: TimeMap) -> PropertyValue<Value> {
        switch self {
        case .value:
            self

        case let .keyframes(keyframes):
            .keyframes(keyframes.map { keyframe in
                TimedValue(
                    index: keyframe.index,
                    at: clock.sequenceTime(ofClipTime: keyframe.at),
                    value: keyframe.value,
                    ease: keyframe.ease
                )
            })
        }
    }

    // MARK: - Private
}

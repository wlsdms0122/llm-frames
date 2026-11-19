//
//  LookProperty.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A key of a clip's look as written: its static value and the value each keyframe that writes it gives, on the clip's
// clock. A `null` in a keyframe is kept, since it points at the merged value.
struct LookProperty: Equatable, Sendable {
    // MARK: - Property
    let written: JSONValue?
    let keyframes: [PropertyKeyframe<JSONValue>]

    // MARK: - Initializer
    init(
        written: JSONValue? = nil,
        keyframes: [PropertyKeyframe<JSONValue>] = []
    ) {
        self.written = written
        self.keyframes = keyframes
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  KeyframeInstant.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `index` is the keyframe's place in the clip's `keyframes`.
struct KeyframeInstant: Equatable, Sendable {
    // MARK: - Property
    let index: Int
    let at: Double
    let properties: [String]

    // MARK: - Initializer
    init(
        index: Int,
        at: Double,
        properties: [String]
    ) {
        self.index = index
        self.at = at
        self.properties = properties
    }

    // MARK: - Public
    func moved(to at: Double) -> KeyframeInstant {
        KeyframeInstant(index: index, at: at, properties: properties)
    }

    // MARK: - Private
}

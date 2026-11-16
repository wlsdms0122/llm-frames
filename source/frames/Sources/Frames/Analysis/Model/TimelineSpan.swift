//
//  TimelineSpan.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// One span of a clip's animation: the preset it comes from, nil where a resolved document keeps no name, and its
// length, `seconds` for an entrance or exit and `period` for a loop.
struct TimelineSpan: Equatable, Sendable {
    // MARK: - Property
    let preset: String?
    let length: Double

    // MARK: - Initializer
    init(preset: String?, length: Double) {
        self.preset = preset
        self.length = length
    }

    // MARK: - Public
    // MARK: - Private
}

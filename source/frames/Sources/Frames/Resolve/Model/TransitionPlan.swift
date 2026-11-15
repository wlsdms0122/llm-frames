//
//  TransitionPlan.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A transition centred on the edit point of the clip it brings in. `seconds` is its length after it is cut to what
// fits, `min(transition seconds, previous duration, next duration)`.
struct TransitionPlan: Equatable, Sendable {
    // MARK: - Property
    let preset: String
    let seconds: Double
    let range: TimeRange
    let definition: TransitionPreset

    // MARK: - Initializer
    init(
        preset: String,
        seconds: Double,
        range: TimeRange,
        definition: TransitionPreset
    ) {
        self.preset = preset
        self.seconds = seconds
        self.range = range
        self.definition = definition
    }

    // MARK: - Public
    // MARK: - Private
}

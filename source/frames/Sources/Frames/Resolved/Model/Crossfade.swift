//
//  Crossfade.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A storyline transition as a sound hears it: the range it crossfades over, in the time of the sound's instants, and
// the curve of its preset's `audio`.
struct Crossfade: Equatable, Sendable {
    // MARK: - Property
    let range: TimeRange
    let curve: CrossfadeCurve

    // MARK: - Initializer
    init(
        range: TimeRange,
        curve: CrossfadeCurve
    ) {
        self.range = range
        self.curve = curve
    }

    // MARK: - Public
    // MARK: - Private
}

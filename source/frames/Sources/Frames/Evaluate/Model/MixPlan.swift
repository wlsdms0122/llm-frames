//
//  MixPlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The sound of a whole sequence: its segments in audio entry order, the repeats of a loop in time order. Segments that
// overlap are mixed.
package struct MixPlan: Equatable, Sendable {
    // MARK: - Property
    package let segments: [MixSegment]

    // MARK: - Initializer
    package init(segments: [MixSegment]) {
        self.segments = segments
    }

    // MARK: - Public
    // MARK: - Private
}

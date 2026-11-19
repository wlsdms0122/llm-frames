//
//  Crossfade+Plan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A transition plan as the sounds it crossfades hear it: its range in sequence time and its preset's `audio`.
extension Crossfade {
    // MARK: - Property
    // MARK: - Initializer
    // A clip's own side of the crossfade moves with its sound's edge, by `offset` seconds.
    init(
        plan: TransitionPlan,
        movedBy offset: Double = 0
    ) {
        let range = TimeRange(start: plan.range.start + offset, end: plan.range.end + offset)
        self.init(range: range, curve: plan.definition.audio)
    }

    // MARK: - Public
    // MARK: - Private
}

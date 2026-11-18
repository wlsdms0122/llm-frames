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
    init(plan: TransitionPlan) {
        self.init(range: plan.range, curve: plan.definition.audio)
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  ResolvedAnimation+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The spans an animation plan takes, without the names of the presets they came from.
extension ResolvedAnimation {
    // MARK: - Property
    // MARK: - Initializer
    init(plan: AnimationPlan) {
        self.init(entrance: plan.entrance?.span, loop: plan.loop?.span, exit: plan.exit?.span, units: plan.units)
    }

    // MARK: - Public
    // MARK: - Private
}

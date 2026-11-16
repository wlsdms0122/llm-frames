//
//  ResolvedLabel+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A label plan with its text's fonts pinned.
extension ResolvedLabel {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: LabelPlan,
        hashes: any FileHashProvider
    ) throws {
        self.init(
            side: plan.side,
            at: plan.instant,
            text: try ResolvedText(layout: plan.text, hashes: hashes),
            animation: ResolvedAnimation(plan: plan.animation)
        )
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  ResolvedFormat+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A sequence's format as resolve planned it.
extension ResolvedFormat {
    // MARK: - Property
    // MARK: - Initializer
    init(plan: FormatPlan) {
        self.init(
            size: plan.size,
            fps: plan.fps,
            duration: plan.duration,
            background: plan.background,
            content: plan.content,
            conform: plan.conform
        )
    }

    // MARK: - Public
    // MARK: - Private
}

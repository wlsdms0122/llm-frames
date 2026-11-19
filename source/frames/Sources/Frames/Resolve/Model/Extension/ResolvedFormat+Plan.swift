//
//  ResolvedFormat+Plan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

extension ResolvedFormat {
    // MARK: - Property
    // MARK: - Initializer
    init(plan: FormatPlan) {
        self.init(
            size: plan.size,
            fps: plan.fps,
            duration: plan.duration,
            background: plan.background,
            conform: plan.conform,
            colorSpace: plan.colorSpace,
            compositing: plan.compositing
        )
    }

    // MARK: - Public
    // MARK: - Private
}

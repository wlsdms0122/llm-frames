//
//  LabelPlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A shape's label: the side it goes on, chosen at sequence time `instant`, its text as set, and its own animation,
// which runs over the shape's visible window on top of the shape's.
struct LabelPlan: Equatable, Sendable {
    // MARK: - Property
    let side: Side
    let instant: Double
    let text: TextLayout
    let animation: AnimationPlan

    // MARK: - Initializer
    init(
        side: Side,
        instant: Double,
        text: TextLayout,
        animation: AnimationPlan
    ) {
        self.side = side
        self.instant = instant
        self.text = text
        self.animation = animation
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  LabelPlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A shape's label: the side it goes on, chosen at sequence time `instant`, and its text as set.
struct LabelPlan: Equatable, Sendable {
    // MARK: - Property
    let side: Side
    let instant: Double
    let text: TextLayout

    // MARK: - Initializer
    init(
        side: Side,
        instant: Double,
        text: TextLayout
    ) {
        self.side = side
        self.instant = instant
        self.text = text
    }

    // MARK: - Public
    // MARK: - Private
}

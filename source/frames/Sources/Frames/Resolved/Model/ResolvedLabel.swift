//
//  ResolvedLabel.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A shape's label: the side it goes on, the sequence time that side was chosen at, its shaped text, and its own
// animation, combined on top of the shape's over the shape's visible window.
struct ResolvedLabel: Equatable, Sendable {
    // MARK: - Property
    let side: Side
    let at: Double
    let text: ResolvedText
    let animation: ResolvedAnimation

    // MARK: - Initializer
    init(
        side: Side,
        at: Double,
        text: ResolvedText,
        animation: ResolvedAnimation
    ) {
        self.side = side
        self.at = at
        self.text = text
        self.animation = animation
    }

    // MARK: - Public
    // MARK: - Private
}

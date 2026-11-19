//
//  ResolvedHighlight.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A run's highlight: its colour, padding and radius as keyframe lists, and its pieces in line order in the text's box,
// each from the run's ascent to its descent without padding.
struct ResolvedHighlight: Equatable, Sendable {
    // MARK: - Property
    let color: TimedValue
    let padding: TimedValue
    let radius: TimedValue
    let rects: [Rectangle]

    // MARK: - Initializer
    init(
        color: TimedValue,
        padding: TimedValue,
        radius: TimedValue,
        rects: [Rectangle]
    ) {
        self.color = color
        self.padding = padding
        self.radius = radius
        self.rects = rects
    }

    // MARK: - Public
    // MARK: - Private
}

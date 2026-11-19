//
//  ResolvedBackground.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A title's paragraph background: its colour, padding and radius as keyframe lists.
struct ResolvedBackground: Equatable, Sendable {
    // MARK: - Property
    let color: TimedValue
    let padding: TimedValue
    let radius: TimedValue

    // MARK: - Initializer
    init(
        color: TimedValue,
        padding: TimedValue,
        radius: TimedValue
    ) {
        self.color = color
        self.padding = padding
        self.radius = radius
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  ResolvedMediaAppearance.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How a media clip's picture fills its box: how its crop was conformed, and the radius of the box's corners, its
// border and its shadow as timed values in output pixels, `off` where it takes none.
struct ResolvedMediaAppearance: Equatable, Sendable {
    // MARK: - Property
    let conform: Conform
    let radius: TimedValue
    let border: TimedValue
    let shadow: TimedValue

    // MARK: - Initializer
    init(
        conform: Conform,
        radius: TimedValue,
        border: TimedValue,
        shadow: TimedValue
    ) {
        self.conform = conform
        self.radius = radius
        self.border = border
        self.shadow = shadow
    }

    // MARK: - Public
    // MARK: - Private
}

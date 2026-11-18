//
//  ResolvedMediaAppearance.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How a media clip's picture fills its box: how its crop was conformed, the radius of the box's corners in output
// pixels, and its border and shadow when it takes them.
struct ResolvedMediaAppearance: Equatable, Sendable {
    // MARK: - Property
    let conform: Conform
    let radius: Double
    let border: MediaBorder?
    let shadow: DropShadow?

    // MARK: - Initializer
    init(
        conform: Conform,
        radius: Double,
        border: MediaBorder?,
        shadow: DropShadow?
    ) {
        self.conform = conform
        self.radius = radius
        self.border = border
        self.shadow = shadow
    }

    // MARK: - Public
    // MARK: - Private
}

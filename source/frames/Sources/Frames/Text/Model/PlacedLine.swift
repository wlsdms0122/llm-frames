//
//  PlacedLine.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A line as it is set: its width at the static tracking and its grapheme clusters in order, up to its last visible
// one, since the spaces that end a line hang outside it and move nothing.
struct PlacedLine: Equatable, Sendable {
    // MARK: - Property
    let width: Double
    let clusters: [GlyphRange]

    // MARK: - Initializer
    init(
        width: Double,
        clusters: [GlyphRange]
    ) {
        self.width = width
        self.clusters = clusters
    }

    // MARK: - Public
    // MARK: - Private
}

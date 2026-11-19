//
//  PlacedCluster.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A grapheme cluster as set on its line: its glyphs, its text, and its span across the line from the origin of its
// first glyph to the end of the advance of its last. A cluster set inside the glyph of the one before it has no glyphs
// of its own and that glyph's span.
struct PlacedCluster: Equatable, Sendable {
    // MARK: - Property
    let glyphs: GlyphRange
    let character: Character
    let start: Double
    let end: Double

    // MARK: - Initializer
    init(
        glyphs: GlyphRange,
        character: Character,
        start: Double,
        end: Double
    ) {
        self.glyphs = glyphs
        self.character = character
        self.start = start
        self.end = end
    }

    // MARK: - Public
    // MARK: - Private
}

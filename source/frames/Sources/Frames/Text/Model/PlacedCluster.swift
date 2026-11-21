//
//  PlacedCluster.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A grapheme cluster as set on its line: its glyphs, its range of the title's text in Unicode scalars, and `advance`,
// the sum of its glyphs' advances, which holds no tracking. Its glyph box starts at its first glyph's pen. A later
// character of a group of glyphs has no glyph of its own: a range of count 0 after its group's glyphs, `advance` 0,
// lying where its group's first character lies.
struct PlacedCluster: Equatable, Sendable {
    // MARK: - Property
    let glyphs: GlyphRange
    let range: Range<Int>
    let advance: Double

    // MARK: - Initializer
    init(
        glyphs: GlyphRange,
        range: Range<Int>,
        advance: Double
    ) {
        self.glyphs = glyphs
        self.range = range
        self.advance = advance
    }

    // MARK: - Public
    // MARK: - Private
}

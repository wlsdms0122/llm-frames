//
//  PlacedCluster.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A grapheme cluster as set on its line: its glyphs, its range of the title's text in Unicode scalars, `advance`, the
// sum of its glyphs' advances, which holds no tracking, and `level`, the embedding level it lies at on its line after
// rule L1 of UAX #9, which orders it there, and `cursiveScripts`, the ISO 15924 codes of the cursive scripts it is a
// letter of, which take no tracking between two of their letters. Its glyph box starts at its first glyph's pen. A
// later character of a group of glyphs has no glyph of its own: a range of count 0 after its group's glyphs, `advance`
// 0, lying where its group's first character lies.
struct PlacedCluster: Equatable, Sendable {
    // MARK: - Property
    let glyphs: GlyphRange
    let range: Range<Int>
    let advance: Double
    let level: Int
    let cursiveScripts: [String]

    // MARK: - Initializer
    init(
        glyphs: GlyphRange,
        range: Range<Int>,
        advance: Double,
        level: Int = 0,
        cursiveScripts: [String] = []
    ) {
        self.glyphs = glyphs
        self.range = range
        self.advance = advance
        self.level = level
        self.cursiveScripts = cursiveScripts
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  GlyphRange.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Glyphs of one glyph run: `count` glyphs from its `first`, the run its index among the text's glyph runs. A later
// character of a group of glyphs, as a ligature sets two characters in one glyph, is a range of count 0 after the
// group's glyphs.
struct GlyphRange: Equatable, Sendable {
    // MARK: - Property
    let run: Int
    let first: Int
    let count: Int

    // MARK: - Initializer
    init(
        run: Int,
        first: Int,
        count: Int
    ) {
        self.run = run
        self.first = first
        self.count = count
    }

    // MARK: - Public
    // The indices of its glyphs among its run's glyphs.
    var glyphs: Range<Int> {
        first..<(first + count)
    }

    // MARK: - Private
}

//
//  GlyphRange.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Glyphs of one glyph run: `count` glyphs from its `first`, the run its index among the text's glyph runs. A grapheme
// cluster set inside the glyph of the one before it, as a ligature sets two, is a range of count 0 after that glyph.
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
    // MARK: - Private
}

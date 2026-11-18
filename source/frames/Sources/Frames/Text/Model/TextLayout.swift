//
//  TextLayout.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Text as resolve set it: the box it fills in output pixels, its background's padding included, the number of lines,
// its glyph runs placed in that box, each with its own stroke, and the background behind them.
struct TextLayout: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let lineCount: Int
    let runs: [GlyphRun]
    let background: TextBackground?

    // MARK: - Initializer
    init(
        size: Size,
        lineCount: Int,
        runs: [GlyphRun],
        background: TextBackground?
    ) {
        self.size = size
        self.lineCount = lineCount
        self.runs = runs
        self.background = background
    }

    // MARK: - Public
    // MARK: - Private
}

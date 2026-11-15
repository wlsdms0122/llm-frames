//
//  TextLayout.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Text as resolve set it: the box it fills in output pixels, its background's padding included, the number of lines,
// and its glyph runs placed in that box, with the stroke and background they are drawn with.
struct TextLayout: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let lineCount: Int
    let runs: [GlyphRun]
    let stroke: TextStroke?
    let background: TextBackground?

    // MARK: - Initializer
    init(
        size: Size,
        lineCount: Int,
        runs: [GlyphRun],
        stroke: TextStroke?,
        background: TextBackground?
    ) {
        self.size = size
        self.lineCount = lineCount
        self.runs = runs
        self.stroke = stroke
        self.background = background
    }

    // MARK: - Public
    // MARK: - Private
}

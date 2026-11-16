//
//  ResolvedText.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A title or label as shaped: its box size in output pixels, how many lines it was set on, its background and stroke,
// and its glyph runs.
struct ResolvedText: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let lineCount: Int
    let background: TextBackground?
    let stroke: TextStroke?
    let runs: [ResolvedGlyphRun]

    // MARK: - Initializer
    init(
        size: Size,
        lineCount: Int,
        background: TextBackground?,
        stroke: TextStroke?,
        runs: [ResolvedGlyphRun]
    ) {
        self.size = size
        self.lineCount = lineCount
        self.background = background
        self.stroke = stroke
        self.runs = runs
    }

    // MARK: - Public
    // MARK: - Private
}

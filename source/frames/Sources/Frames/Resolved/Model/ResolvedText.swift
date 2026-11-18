//
//  ResolvedText.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A title or label as shaped: its box size in output pixels, how many lines it was set on, its background, and its
// glyph runs, each with its own stroke.
struct ResolvedText: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let lineCount: Int
    let background: TextBackground?
    let runs: [ResolvedGlyphRun]

    // MARK: - Initializer
    init(
        size: Size,
        lineCount: Int,
        background: TextBackground?,
        runs: [ResolvedGlyphRun]
    ) {
        self.size = size
        self.lineCount = lineCount
        self.background = background
        self.runs = runs
    }

    // MARK: - Public
    // MARK: - Private
}

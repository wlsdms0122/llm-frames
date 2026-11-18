//
//  ResolvedText.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A title or label as shaped: its box size in output pixels, its background, and its glyph runs, each with its own
// stroke.
struct ResolvedText: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let background: TextBackground?
    let runs: [ResolvedGlyphRun]

    // MARK: - Initializer
    init(
        size: Size,
        background: TextBackground?,
        runs: [ResolvedGlyphRun]
    ) {
        self.size = size
        self.background = background
        self.runs = runs
    }

    // MARK: - Public
    // MARK: - Private
}

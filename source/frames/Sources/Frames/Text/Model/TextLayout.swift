//
//  TextLayout.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// `size` is the box the text fills in output pixels, its background's padding included, and `runs` are placed in that
// box.
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

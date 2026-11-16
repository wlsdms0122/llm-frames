//
//  GlyphsItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Shaped glyphs with their outline and the box behind them, in the text's own box.
struct GlyphsItem: Equatable, Sendable {
    // MARK: - Property
    let runs: [ResolvedGlyphRun]
    let stroke: TextStroke?
    let background: GlyphBackground?

    // MARK: - Initializer
    init(
        runs: [ResolvedGlyphRun],
        stroke: TextStroke?,
        background: GlyphBackground?
    ) {
        self.runs = runs
        self.stroke = stroke
        self.background = background
    }

    // MARK: - Public
    // MARK: - Private
}

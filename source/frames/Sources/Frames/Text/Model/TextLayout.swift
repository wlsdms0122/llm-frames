//
//  TextLayout.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// `size` is the box the text fills in output pixels, its background's padding included, and `runs` are placed in that
// box, each line placed by `align`. `width` is the width the text wraps at, nil for text that breaks only at `\n`.
struct TextLayout: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let width: Double?
    let lines: [PlacedLine]
    let runs: [GlyphRun]
    let background: TextBackground?
    let align: TextAlignment

    var lineCount: Int {
        lines.count
    }

    // MARK: - Initializer
    init(
        size: Size,
        width: Double?,
        lines: [PlacedLine],
        runs: [GlyphRun],
        background: TextBackground?,
        align: TextAlignment
    ) {
        self.size = size
        self.width = width
        self.lines = lines
        self.runs = runs
        self.background = background
        self.align = align
    }

    // MARK: - Public
    // MARK: - Private
}

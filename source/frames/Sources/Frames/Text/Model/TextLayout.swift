//
//  TextLayout.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// `size` is the box the text fills in output pixels, its background's padding included, and `runs` are placed in that
// box, each line placed by `align` and `lineHeight` below the one before it. `textBox` is the box inside it that the
// lines fill, and `width` the width the text wraps at, nil for text that breaks only at `\n`.
struct TextLayout: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let textBox: Rectangle
    let width: Double?
    let lines: [PlacedLine]
    let runs: [GlyphRun]
    let background: TextBackground?
    let align: TextAlignment
    let lineHeight: Double

    var lineCount: Int {
        lines.count
    }

    // MARK: - Initializer
    init(
        size: Size,
        textBox: Rectangle,
        width: Double?,
        lines: [PlacedLine],
        runs: [GlyphRun],
        background: TextBackground?,
        align: TextAlignment,
        lineHeight: Double
    ) {
        self.size = size
        self.textBox = textBox
        self.width = width
        self.lines = lines
        self.runs = runs
        self.background = background
        self.align = align
        self.lineHeight = lineHeight
    }

    // MARK: - Public
    // MARK: - Private
}

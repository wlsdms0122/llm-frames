//
//  TextLayout.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// `text` is the text of its runs joined in order, which every range counts in Unicode scalars, and `words` its words in
// reading order, each its range, a word a line breaks inside one range. `size` is the box the
// text fills in output pixels, its background's padding included, and `runs` are placed in that box, each line placed
// by `align` along its inline axis and `lineHeight` toward block-end from the one before it, as `writingMode` turns
// them. `textBox` is the box inside it that the lines fill, and `width`
// the width the text wraps at, nil for text that breaks only at `\n`. `units` are the units of a title animated by
// unit, and nil for other text. `writingMode` and `direction` are the writing mode and the paragraph direction the text
// was laid out in, and `align` the alignment its lines were placed by, its default resolved.
struct TextLayout: Equatable, Sendable {
    // MARK: - Property
    let text: String
    let words: [Range<Int>]
    let size: Size
    let textBox: Rectangle
    let width: Double?
    let lines: [PlacedLine]
    let runs: [GlyphRun]
    let units: [PlacedUnit]?
    let background: TextBackground?
    let writingMode: WritingMode
    let direction: TextDirection
    let align: TextAlignment
    let lineHeight: Double

    var lineCount: Int {
        lines.count
    }

    // MARK: - Initializer
    init(
        text: String,
        words: [Range<Int>],
        size: Size,
        textBox: Rectangle,
        width: Double?,
        lines: [PlacedLine],
        runs: [GlyphRun],
        units: [PlacedUnit]? = nil,
        background: TextBackground?,
        writingMode: WritingMode = .horizontalTopToBottom,
        direction: TextDirection = .ltr,
        align: TextAlignment,
        lineHeight: Double
    ) {
        self.text = text
        self.words = words
        self.size = size
        self.textBox = textBox
        self.width = width
        self.lines = lines
        self.runs = runs
        self.units = units
        self.background = background
        self.writingMode = writingMode
        self.direction = direction
        self.align = align
        self.lineHeight = lineHeight
    }

    // MARK: - Public
    // MARK: - Private
}

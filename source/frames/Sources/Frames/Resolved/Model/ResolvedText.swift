//
//  ResolvedText.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A title or label as shaped: its box size in output pixels and its `textBox` in that box, both at the static
// tracking, line height and background padding, the `width` it wraps at (nil for text without one), its background,
// the `writingMode` and the paragraph `direction` it was laid out in, its lines' `align`, its `lineHeight` timed, and
// its glyph runs. `text` is the text its ranges count in Unicode scalars, `words` its words in reading order, each its
// range, and `lines` its lines, along and with which evaluation moves the glyphs. `units` is nil, or, for a title
// animated by unit, its units in reading order.
struct ResolvedText: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let textBox: Rectangle
    let width: Double?
    let background: ResolvedBackground?
    let writingMode: WritingMode
    let direction: TextDirection
    let align: TextAlignment
    let lineHeight: TimedValue
    let text: String
    let words: [Range<Int>]
    let lines: [PlacedLine]
    let units: [PlacedUnit]?
    let runs: [ResolvedGlyphRun]

    // MARK: - Initializer
    init(
        size: Size,
        textBox: Rectangle,
        width: Double?,
        background: ResolvedBackground?,
        writingMode: WritingMode,
        direction: TextDirection,
        align: TextAlignment,
        lineHeight: TimedValue,
        text: String,
        words: [Range<Int>],
        lines: [PlacedLine],
        units: [PlacedUnit]?,
        runs: [ResolvedGlyphRun]
    ) {
        self.size = size
        self.textBox = textBox
        self.width = width
        self.background = background
        self.writingMode = writingMode
        self.direction = direction
        self.align = align
        self.lineHeight = lineHeight
        self.text = text
        self.words = words
        self.lines = lines
        self.units = units
        self.runs = runs
    }

    // MARK: - Public
    // MARK: - Private
}

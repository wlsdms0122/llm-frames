//
//  ResolvedText.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A title or label as shaped: its box size in output pixels at the static tracking, the `width` it wraps at (nil for
// text without one), its background, its lines' `align`, and its glyph runs. `lines` is nil, or, for a title whose
// tracking takes keyframes, its lines, along which evaluation moves the glyphs.
struct ResolvedText: Equatable, Sendable {
    // MARK: - Property
    let size: Size
    let width: Double?
    let background: TextBackground?
    let align: TextAlignment
    let lines: [PlacedLine]?
    let runs: [ResolvedGlyphRun]

    // MARK: - Initializer
    init(
        size: Size,
        width: Double? = nil,
        background: TextBackground?,
        align: TextAlignment = .left,
        lines: [PlacedLine]? = nil,
        runs: [ResolvedGlyphRun]
    ) {
        self.size = size
        self.width = width
        self.background = background
        self.align = align
        self.lines = lines
        self.runs = runs
    }

    // MARK: - Public
    // MARK: - Private
}

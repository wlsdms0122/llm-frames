//
//  GlyphRun.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Glyphs of one line drawn in one face, size, colour and stroke, all of one text run, whose index among the text's
// runs is `source`. `highlights` and `underlines` are the pieces of the text run's highlight and underline on this
// line, held by the first glyph run of the text run on it: a highlight piece from the run's ascent to its descent
// without padding, an underline piece on the baseline.
struct GlyphRun: Equatable, Sendable {
    // MARK: - Property
    let source: Int
    let face: FontFace
    let size: Double
    let color: Color
    let stroke: TextStroke?
    let glyphs: [PositionedGlyph]
    let highlights: [Rectangle]
    let underlines: [UnderlinePiece]

    // MARK: - Initializer
    init(
        source: Int,
        face: FontFace,
        size: Double,
        color: Color,
        stroke: TextStroke?,
        glyphs: [PositionedGlyph],
        highlights: [Rectangle] = [],
        underlines: [UnderlinePiece] = []
    ) {
        self.source = source
        self.face = face
        self.size = size
        self.color = color
        self.stroke = stroke
        self.glyphs = glyphs
        self.highlights = highlights
        self.underlines = underlines
    }

    // MARK: - Public
    // MARK: - Private
}

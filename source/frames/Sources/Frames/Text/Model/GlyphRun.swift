//
//  GlyphRun.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Glyphs of one line set in one face and size, all of one text run, whose index among the text's runs is `source`, and
// whose line is the `line`th of the text, in the order they lie on the line, each narrowed about its origin along its
// own horizontal axis by `horizontalScale` and then turned 90 degrees clockwise about it where `isSideways`.
// `staticTracking` is the tracking set between two neighbouring characters with glyphs of their own of which one of its
// characters comes first in the text, in output pixels. `highlights` and `underlines` are the pieces of the text run's
// highlight and underline on this line, one for each stretch of its characters that lie side by side, in the text order
// of their first characters, held by the first glyph run of the text run on it: a highlight piece from the run's ascent
// to its descent without padding, an underline piece on the run's alphabetic baseline.
struct GlyphRun: Equatable, Sendable {
    // MARK: - Property
    let source: Int
    let line: Int
    let face: FontFace
    let size: Double
    let glyphs: [PositionedGlyph]
    let isSideways: Bool
    let horizontalScale: Double
    let staticTracking: Double
    let highlights: [Rectangle]
    let underlines: [UnderlinePiece]

    // MARK: - Initializer
    init(
        source: Int,
        line: Int,
        face: FontFace,
        size: Double,
        glyphs: [PositionedGlyph],
        isSideways: Bool = false,
        horizontalScale: Double = 1,
        staticTracking: Double = 0,
        highlights: [Rectangle] = [],
        underlines: [UnderlinePiece] = []
    ) {
        self.source = source
        self.line = line
        self.face = face
        self.size = size
        self.glyphs = glyphs
        self.isSideways = isSideways
        self.horizontalScale = horizontalScale
        self.staticTracking = staticTracking
        self.highlights = highlights
        self.underlines = underlines
    }

    // MARK: - Public
    // MARK: - Private
}

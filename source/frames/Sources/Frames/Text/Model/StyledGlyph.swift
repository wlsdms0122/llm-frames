//
//  StyledGlyph.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A shaped glyph with the face it was set in, and the run it belongs to: its index among the text's runs, its
// character style and the style's own face. Its offset is into its whole paragraph.
struct StyledGlyph: Equatable, Sendable {
    // MARK: - Property
    let glyph: ShapedGlyph
    let face: FontFace
    let source: Int
    let style: CharacterStyle
    let runFace: FontFace

    // MARK: - Initializer
    init(
        glyph: ShapedGlyph,
        face: FontFace,
        source: Int,
        style: CharacterStyle,
        runFace: FontFace
    ) {
        self.glyph = glyph
        self.face = face
        self.source = source
        self.style = style
        self.runFace = runFace
    }

    // MARK: - Public
    // MARK: - Private
}

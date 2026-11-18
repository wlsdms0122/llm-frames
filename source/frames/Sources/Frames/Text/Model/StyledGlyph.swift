//
//  StyledGlyph.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shaped glyph with the face it was set in and the character style of its run. Its offset is into its whole
// paragraph.
struct StyledGlyph: Equatable, Sendable {
    // MARK: - Property
    let glyph: ShapedGlyph
    let face: FontFace
    let style: CharacterStyle

    // MARK: - Initializer
    init(
        glyph: ShapedGlyph,
        face: FontFace,
        style: CharacterStyle
    ) {
        self.glyph = glyph
        self.face = face
        self.style = style
    }

    // MARK: - Public
    // MARK: - Private
}

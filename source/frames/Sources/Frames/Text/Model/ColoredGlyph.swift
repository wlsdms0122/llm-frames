//
//  ColoredGlyph.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A shaped glyph with the face it was set in and the colour it is drawn in. Its offset is into its whole paragraph.
struct ColoredGlyph: Equatable, Sendable {
    // MARK: - Property
    let glyph: ShapedGlyph
    let face: FontFace
    let color: Color

    // MARK: - Initializer
    init(
        glyph: ShapedGlyph,
        face: FontFace,
        color: Color
    ) {
        self.glyph = glyph
        self.face = face
        self.color = color
    }

    // MARK: - Public
    // MARK: - Private
}

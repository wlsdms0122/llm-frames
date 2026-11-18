//
//  GlyphRun.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Glyphs of one line drawn in one face, size, colour and stroke.
struct GlyphRun: Equatable, Sendable {
    // MARK: - Property
    let face: FontFace
    let size: Double
    let color: Color
    let stroke: TextStroke?
    let glyphs: [PositionedGlyph]

    // MARK: - Initializer
    init(
        face: FontFace,
        size: Double,
        color: Color,
        stroke: TextStroke?,
        glyphs: [PositionedGlyph]
    ) {
        self.face = face
        self.size = size
        self.color = color
        self.stroke = stroke
        self.glyphs = glyphs
    }

    // MARK: - Public
    // MARK: - Private
}

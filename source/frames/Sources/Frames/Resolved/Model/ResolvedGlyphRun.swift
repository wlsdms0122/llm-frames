//
//  ResolvedGlyphRun.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A run of shaped glyphs in one face, size and colour, each glyph's origin in its text's own box.
struct ResolvedGlyphRun: Equatable, Sendable {
    // MARK: - Property
    let font: PinnedFile
    let face: String
    let size: Double
    let color: Color
    let glyphs: [PositionedGlyph]

    // MARK: - Initializer
    init(
        font: PinnedFile,
        face: String,
        size: Double,
        color: Color,
        glyphs: [PositionedGlyph]
    ) {
        self.font = font
        self.face = face
        self.size = size
        self.color = color
        self.glyphs = glyphs
    }

    // MARK: - Public
    // MARK: - Private
}

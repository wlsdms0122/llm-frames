//
//  ResolvedGlyphRun.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A run of shaped glyphs in one face, size and colour, each glyph's origin in its text's own box.
package struct ResolvedGlyphRun: Equatable, Sendable {
    // MARK: - Property
    package let font: PinnedFile
    package let face: String
    package let size: Double
    package let color: Color
    package let glyphs: [PositionedGlyph]

    // MARK: - Initializer
    package init(
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

//
//  ShapedRun.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Glyphs set in one face: the face asked for, or the one the provider fell back to for characters it lacks.
struct ShapedRun: Equatable, Sendable {
    // MARK: - Property
    let face: FontFace
    let glyphs: [ShapedGlyph]

    // MARK: - Initializer
    init(
        face: FontFace,
        glyphs: [ShapedGlyph]
    ) {
        self.face = face
        self.glyphs = glyphs
    }

    // MARK: - Public
    // MARK: - Private
}

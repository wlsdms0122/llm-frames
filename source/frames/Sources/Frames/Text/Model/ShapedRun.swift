//
//  ShapedRun.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Glyphs set in one face: the face asked for, or the one the provider fell back to for characters it lacks.
package struct ShapedRun: Equatable, Sendable {
    // MARK: - Property
    package let face: FontFace
    package let glyphs: [ShapedGlyph]

    // MARK: - Initializer
    package init(
        face: FontFace,
        glyphs: [ShapedGlyph]
    ) {
        self.face = face
        self.glyphs = glyphs
    }

    // MARK: - Public
    // MARK: - Private
}

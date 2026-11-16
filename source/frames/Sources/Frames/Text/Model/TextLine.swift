//
//  TextLine.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The glyphs of one line and its width, without the spaces that hang at its end.
struct TextLine: Equatable, Sendable {
    // MARK: - Property
    let glyphs: [ColoredGlyph]
    let width: Double

    // MARK: - Initializer
    init(
        glyphs: [ColoredGlyph],
        width: Double
    ) {
        self.glyphs = glyphs
        self.width = width
    }

    // MARK: - Public
    // MARK: - Private
}

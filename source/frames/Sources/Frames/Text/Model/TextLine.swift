//
//  TextLine.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// `width` leaves out the spaces that hang at the line's end, and `ascent` and `descent` are the largest among its runs.
struct TextLine: Equatable, Sendable {
    // MARK: - Property
    let glyphs: [StyledGlyph]
    let width: Double
    let ascent: Double
    let descent: Double

    // MARK: - Initializer
    init(
        glyphs: [StyledGlyph],
        width: Double,
        ascent: Double,
        descent: Double
    ) {
        self.glyphs = glyphs
        self.width = width
        self.ascent = ascent
        self.descent = descent
    }

    // MARK: - Public
    // MARK: - Private
}

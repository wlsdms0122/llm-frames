//
//  ShapedGlyph.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A glyph the shaping provider gave: its id in its face, its advance, and `offset`, the index of the first Unicode
// scalar of the text it was shaped from.
struct ShapedGlyph: Equatable, Sendable {
    // MARK: - Property
    let id: Int
    let advance: Double
    let offset: Int

    // MARK: - Initializer
    init(
        id: Int,
        advance: Double,
        offset: Int
    ) {
        self.id = id
        self.advance = advance
        self.offset = offset
    }

    // MARK: - Public
    // MARK: - Private
}

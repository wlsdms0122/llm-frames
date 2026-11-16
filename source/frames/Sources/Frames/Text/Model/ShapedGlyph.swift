//
//  ShapedGlyph.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A glyph the shaping provider gave: its id in its face, its advance, and `offset`, the index of the first Unicode
// scalar of the text it was shaped from.
package struct ShapedGlyph: Equatable, Sendable {
    // MARK: - Property
    package let id: Int
    package let advance: Double
    package let offset: Int

    // MARK: - Initializer
    package init(
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

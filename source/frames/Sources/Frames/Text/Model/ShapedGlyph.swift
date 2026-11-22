//
//  ShapedGlyph.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A glyph the shaping provider gave: its id in its face, its advance, which moves the pen along the line, `offset`,
// the index of the first Unicode scalar of the text it was shaped from, and `placementOffset`, the move from the pen to
// the origin it is drawn from, x along the line and y toward its line-under side. It holds what a font's GPOS table
// places, a mark over its base, and for an upright glyph in a vertical line the move from its vertical origin, which
// lies at the pen, to its origin.
package struct ShapedGlyph: Equatable, Sendable {
    // MARK: - Property
    package let id: Int
    package let advance: Double
    package let offset: Int
    package let placementOffset: Point

    // MARK: - Initializer
    package init(
        id: Int,
        advance: Double,
        offset: Int,
        placementOffset: Point
    ) {
        self.id = id
        self.advance = advance
        self.offset = offset
        self.placementOffset = placementOffset
    }

    // MARK: - Public
    // MARK: - Private
}

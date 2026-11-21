//
//  ShapedGlyph.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A glyph the shaping provider gave: its id in its face, its advance, which moves the pen along the line, `offset`,
// the index of the first Unicode scalar of the text it was shaped from, and `placementOffset`, where it is drawn from
// the pen, y down, as a font's GPOS table places a mark over its base.
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

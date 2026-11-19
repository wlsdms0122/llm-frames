//
//  PlacedUnit.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A unit of a title animated by unit: its glyphs as ranges of the text's glyph runs in reading order, its box in the
// text's box, and the parts of highlight and underline pieces it carries. As set, the box runs across its glyphs and
// down its line; as resolved, it also holds their strokes and its parts at their widest.
struct PlacedUnit: Equatable, Sendable {
    // MARK: - Property
    let glyphs: [GlyphRange]
    let box: Rectangle
    let parts: [UnitPart]

    // MARK: - Initializer
    init(
        glyphs: [GlyphRange],
        box: Rectangle,
        parts: [UnitPart]
    ) {
        self.glyphs = glyphs
        self.box = box
        self.parts = parts
    }

    // MARK: - Public
    // MARK: - Private
}

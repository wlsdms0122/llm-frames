//
//  PlacedUnit.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A unit of a title animated by unit: its glyphs as ranges of the text's glyph runs in reading order, the parts of
// highlight and underline pieces it carries, and two boxes in the text's box. `glyphBox` runs across its glyphs and down
// its line, without their strokes. `box` is the unit's box its motion acts about: as set, its glyph box; as resolved, it
// also holds their strokes and its parts at their widest.
struct PlacedUnit: Equatable, Sendable {
    // MARK: - Property
    let glyphs: [GlyphRange]
    let glyphBox: Rectangle
    let box: Rectangle
    let parts: [UnitPart]

    // MARK: - Initializer
    init(
        glyphs: [GlyphRange],
        glyphBox: Rectangle,
        box: Rectangle,
        parts: [UnitPart]
    ) {
        self.glyphs = glyphs
        self.glyphBox = glyphBox
        self.box = box
        self.parts = parts
    }

    // MARK: - Public
    // MARK: - Private
}

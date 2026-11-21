//
//  PositionedGlyph.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A glyph placed in its text's box: its id, its pen position on the baseline, and `placementOffset`, where it is drawn
// from the pen, y down. A glyph is drawn at the pen with its placement offset added. A display list's glyph is at the
// position it is drawn at, with no placement offset.
package struct PositionedGlyph: Equatable, Sendable {
    // MARK: - Property
    package let id: Int
    package let x: Double
    package let y: Double
    package let placementOffset: Point

    // MARK: - Initializer
    package init(
        id: Int,
        x: Double,
        y: Double,
        placementOffset: Point = Point(x: 0, y: 0)
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.placementOffset = placementOffset
    }

    // MARK: - Public
    // MARK: - Private
}

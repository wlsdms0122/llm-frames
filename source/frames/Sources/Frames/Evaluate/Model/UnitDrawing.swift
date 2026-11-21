//
//  UnitDrawing.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// What a unit's glyphs item draws of its unit: the one step `layer` of the drawing order, of the unit at `index` among
// its title's units in reading order, in the unit's `box`, which holds its stroke and its parts.
package struct UnitDrawing: Equatable, Sendable {
    // MARK: - Property
    package let layer: GlyphLayer
    package let index: Int
    package let box: Rectangle

    // MARK: - Initializer
    package init(
        layer: GlyphLayer,
        index: Int,
        box: Rectangle
    ) {
        self.layer = layer
        self.index = index
        self.box = box
    }

    // MARK: - Public
    // MARK: - Private
}

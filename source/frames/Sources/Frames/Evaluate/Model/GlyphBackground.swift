//
//  GlyphBackground.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The box drawn behind a glyphs item, in the text's own box, with corners of `radius`.
package struct GlyphBackground: Equatable, Sendable {
    // MARK: - Property
    package let rectangle: Rectangle
    package let radius: Double
    package let color: Color

    // MARK: - Initializer
    package init(
        rectangle: Rectangle,
        radius: Double,
        color: Color
    ) {
        self.rectangle = rectangle
        self.radius = radius
        self.color = color
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  GlyphBackground.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The box drawn behind a glyphs item, in the text's own box, with corners of `radius`.
struct GlyphBackground: Equatable, Sendable {
    // MARK: - Property
    let rectangle: Rectangle
    let radius: Double
    let color: Color

    // MARK: - Initializer
    init(
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

//
//  DrawnHighlight.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A run's highlight as a `glyphs` item draws it: each rectangle a piece grown by its padding, with corners of `radius`.
// `bands` is nil, or, in a unit's item, one `[x0, x1]` for each piece, the part of it the unit carries.
package struct DrawnHighlight: Equatable, Sendable {
    // MARK: - Property
    package let rects: [Rectangle]
    package let radius: Double
    package let color: Color
    package let bands: [ClosedRange<Double>]?

    // MARK: - Initializer
    package init(
        rects: [Rectangle],
        radius: Double,
        color: Color,
        bands: [ClosedRange<Double>]?
    ) {
        self.rects = rects
        self.radius = radius
        self.color = color
        self.bands = bands
    }

    // MARK: - Public
    // MARK: - Private
}

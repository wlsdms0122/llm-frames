//
//  DrawnUnderline.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A run's underline as a `glyphs` item draws it: each rectangle a band across a piece. `bands` is nil, or, in a unit's
// item, one `[x0, x1]` for each piece, the part of it the unit carries.
package struct DrawnUnderline: Equatable, Sendable {
    // MARK: - Property
    package let rects: [Rectangle]
    package let color: Color
    package let bands: [ClosedRange<Double>]?

    // MARK: - Initializer
    package init(
        rects: [Rectangle],
        color: Color,
        bands: [ClosedRange<Double>]?
    ) {
        self.rects = rects
        self.color = color
        self.bands = bands
    }

    // MARK: - Public
    // MARK: - Private
}

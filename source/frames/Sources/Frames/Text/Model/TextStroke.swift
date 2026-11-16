//
//  TextStroke.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// An outline around the glyphs, its width in output pixels.
package struct TextStroke: Equatable, Sendable {
    // MARK: - Property
    package let width: Double
    package let color: Color

    // MARK: - Initializer
    package init(
        width: Double,
        color: Color
    ) {
        self.width = width
        self.color = color
    }

    // MARK: - Public
    // MARK: - Private
}

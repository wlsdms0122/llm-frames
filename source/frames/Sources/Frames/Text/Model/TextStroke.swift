//
//  TextStroke.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// An outline around the glyphs, its width in output pixels.
struct TextStroke: Equatable, Sendable {
    // MARK: - Property
    let width: Double
    let color: Color

    // MARK: - Initializer
    init(
        width: Double,
        color: Color
    ) {
        self.width = width
        self.color = color
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  PositionedGlyph.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A glyph placed in its text's box: its id and the origin of its baseline.
package struct PositionedGlyph: Equatable, Sendable {
    // MARK: - Property
    package let id: Int
    package let x: Double
    package let y: Double

    // MARK: - Initializer
    package init(
        id: Int,
        x: Double,
        y: Double
    ) {
        self.id = id
        self.x = x
        self.y = y
    }

    // MARK: - Public
    // MARK: - Private
}

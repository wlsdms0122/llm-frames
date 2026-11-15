//
//  PositionedGlyph.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A glyph placed in its text's box: its id and the origin of its baseline.
struct PositionedGlyph: Equatable, Sendable {
    // MARK: - Property
    let id: Int
    let x: Double
    let y: Double

    // MARK: - Initializer
    init(
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

//
//  PieceMove.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// How far the two ends of a highlight or underline piece move at an instant: its start with its first glyph and its
// end with its last.
struct PieceMove: Equatable, Sendable {
    // MARK: - Property
    let start: Point
    let end: Point

    // MARK: - Initializer
    init(
        start: Point,
        end: Point
    ) {
        self.start = start
        self.end = end
    }

    // MARK: - Public
    // MARK: - Private
}

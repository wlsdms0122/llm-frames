//
//  UnitPart.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The part of a highlight and underline piece a unit carries: the piece at `piece` among the pieces of the glyph run
// at `run`, and `span` along the line in the text's box, on its inline axis. The first part of a piece starts at the piece's start and
// the last ends at its end, the piece's own ends, which reach its padding where it is drawn.
struct UnitPart: Equatable, Sendable {
    // MARK: - Property
    let run: Int
    let piece: Int
    let span: ClosedRange<Double>

    // MARK: - Initializer
    init(
        run: Int,
        piece: Int,
        span: ClosedRange<Double>
    ) {
        self.run = run
        self.piece = piece
        self.span = span
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  UnderlinePiece.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The span an underline is drawn across on one line: from the point at `x` and `y` on its run's alphabetic baseline,
// `width` long along the line.
struct UnderlinePiece: Equatable, Sendable {
    // MARK: - Property
    let x: Double
    let y: Double
    let width: Double

    // MARK: - Initializer
    init(
        x: Double,
        y: Double,
        width: Double
    ) {
        self.x = x
        self.y = y
        self.width = width
    }

    // MARK: - Public
    // MARK: - Private
}

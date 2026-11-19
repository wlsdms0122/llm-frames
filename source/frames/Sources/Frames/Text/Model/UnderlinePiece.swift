//
//  UnderlinePiece.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The span an underline is drawn across on one line: from `x`, `width` long, on the baseline at `y`.
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

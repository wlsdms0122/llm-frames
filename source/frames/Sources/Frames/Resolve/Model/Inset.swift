//
//  Inset.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How far the content rect lies inside the output frame on each side, in output pixels.
struct Inset: Equatable, Sendable {
    // MARK: - Property
    static let zero = Inset(top: 0, right: 0, bottom: 0, left: 0)

    let top: Double
    let right: Double
    let bottom: Double
    let left: Double

    // MARK: - Initializer
    init(
        top: Double,
        right: Double,
        bottom: Double,
        left: Double
    ) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }

    // MARK: - Public
    // MARK: - Private
}

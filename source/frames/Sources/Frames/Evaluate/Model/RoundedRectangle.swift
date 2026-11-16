//
//  RoundedRectangle.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A rectangle whose corners are circular arcs of `radius`.
struct RoundedRectangle: Equatable, Sendable {
    // MARK: - Property
    let rectangle: Rectangle
    let radius: Double

    // MARK: - Initializer
    init(
        rectangle: Rectangle,
        radius: Double
    ) {
        self.rectangle = rectangle
        self.radius = radius
    }

    // MARK: - Public
    // MARK: - Private
}

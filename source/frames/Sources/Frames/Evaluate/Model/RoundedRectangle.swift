//
//  RoundedRectangle.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A rectangle whose corners are circular arcs of `radius`.
package struct RoundedRectangle: Equatable, Sendable {
    // MARK: - Property
    package let rectangle: Rectangle
    package let radius: Double

    // MARK: - Initializer
    package init(
        rectangle: Rectangle,
        radius: Double
    ) {
        self.rectangle = rectangle
        self.radius = radius
    }

    // MARK: - Public
    // MARK: - Private
}

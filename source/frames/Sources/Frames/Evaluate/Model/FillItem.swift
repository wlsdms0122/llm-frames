//
//  FillItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A filled rectangle with corners of `radius`, and an optional rounded hole left unfilled.
package struct FillItem: Equatable, Sendable {
    // MARK: - Property
    package let rectangle: Rectangle
    package let radius: Double
    package let color: Color
    package let hole: RoundedRectangle?

    // MARK: - Initializer
    package init(
        rectangle: Rectangle,
        radius: Double = 0,
        color: Color,
        hole: RoundedRectangle? = nil
    ) {
        self.rectangle = rectangle
        self.radius = radius
        self.color = color
        self.hole = hole
    }

    // MARK: - Public
    // MARK: - Private
}

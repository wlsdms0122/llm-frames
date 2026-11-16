//
//  StrokeItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The outline of a rectangle with corners of `radius`, `width` wide and centred on its edge, drawn from the top left
// clockwise as far as `trim` of its length (0 to 1).
package struct StrokeItem: Equatable, Sendable {
    // MARK: - Property
    package let rectangle: Rectangle
    package let radius: Double
    package let width: Double
    package let color: Color
    package let trim: Double

    // MARK: - Initializer
    package init(
        rectangle: Rectangle,
        radius: Double,
        width: Double,
        color: Color,
        trim: Double = 1
    ) {
        self.rectangle = rectangle
        self.radius = radius
        self.width = width
        self.color = color
        self.trim = trim
    }

    // A border: a square-cornered stroke that lies inside its rectangle, its edge `width / 2` in from the rectangle's.
    package init(
        border rectangle: Rectangle,
        width: Double,
        color: Color
    ) {
        self.init(
            rectangle: Rectangle(
                x: rectangle.x + width / 2,
                y: rectangle.y + width / 2,
                width: rectangle.width - width,
                height: rectangle.height - width
            ),
            radius: 0,
            width: width,
            color: color
        )
    }

    // MARK: - Public
    // MARK: - Private
}

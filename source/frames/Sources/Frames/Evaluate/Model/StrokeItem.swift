//
//  StrokeItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The outline of a rectangle with corners of `radius`, `width` wide and centred on its edge, drawn from the top left
// clockwise as far as `trim` of its length (0 to 1).
struct StrokeItem: Equatable, Sendable {
    // MARK: - Property
    let rectangle: Rectangle
    let radius: Double
    let width: Double
    let color: Color
    let trim: Double

    // MARK: - Initializer
    init(
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

    // MARK: - Public
    // MARK: - Private
}

//
//  FillItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A filled rectangle with corners of `radius`, and an optional rounded hole left unfilled.
struct FillItem: Equatable, Sendable {
    // MARK: - Property
    let rectangle: Rectangle
    let radius: Double
    let color: Color
    let hole: RoundedRectangle?

    // MARK: - Initializer
    init(
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

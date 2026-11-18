//
//  DropShadow.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A drop shadow below a drawn picture: the standard deviation of its blur, its offset and its colour.
package struct DropShadow: Equatable, Sendable {
    // MARK: - Property
    package let radius: Double
    package let offset: Point
    package let color: Color

    // MARK: - Initializer
    package init(
        radius: Double,
        offset: Point,
        color: Color
    ) {
        self.radius = radius
        self.offset = offset
        self.color = color
    }

    // MARK: - Public
    // MARK: - Private
}

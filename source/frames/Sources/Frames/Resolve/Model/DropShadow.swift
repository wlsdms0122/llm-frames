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
    // The region the shadow of `rectangle` darkens: the rectangle at the offset, out to three standard deviations of
    // the blur, past which a Gaussian leaves no visible trace.
    package func castBounds(of rectangle: Rectangle) -> Rectangle {
        Rectangle(
            x: rectangle.x + offset.x,
            y: rectangle.y + offset.y,
            width: rectangle.width,
            height: rectangle.height
        )
        .grown(by: radius * 3)
    }

    // MARK: - Private
}

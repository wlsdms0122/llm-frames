//
//  Quad.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A quadrilateral (quad) in media pixels: a target's top left, top right, bottom right and bottom left corners in that
// order, as the target faces on the frame it was found.
package struct Quad: Equatable, Sendable {
    // MARK: - Property
    package let topLeft: Point
    package let topRight: Point
    package let bottomRight: Point
    package let bottomLeft: Point

    package var corners: [Point] {
        [topLeft, topRight, bottomRight, bottomLeft]
    }

    package var centroid: Point {
        Point.centroid(of: corners)
    }

    // MARK: - Initializer
    package init(
        topLeft: Point,
        topRight: Point,
        bottomRight: Point,
        bottomLeft: Point
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    // A rectangle's four corners, as a tracker is given a rectangle.
    package init(_ rectangle: Rectangle) {
        self.init(
            topLeft: Point(x: rectangle.x, y: rectangle.y),
            topRight: Point(x: rectangle.x + rectangle.width, y: rectangle.y),
            bottomRight: Point(x: rectangle.x + rectangle.width, y: rectangle.y + rectangle.height),
            bottomLeft: Point(x: rectangle.x, y: rectangle.y + rectangle.height)
        )
    }

    // MARK: - Public
    package func applying(_ transform: AffineTransform) -> Quad {
        Quad(
            topLeft: transform.apply(to: topLeft),
            topRight: transform.apply(to: topRight),
            bottomRight: transform.apply(to: bottomRight),
            bottomLeft: transform.apply(to: bottomLeft)
        )
    }

    // MARK: - Private
}

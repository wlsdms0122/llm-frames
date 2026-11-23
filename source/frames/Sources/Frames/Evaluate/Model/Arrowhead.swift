//
//  Arrowhead.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// An isosceles triangle with its tip at an end of the drawn stroke, pointing along `axis`, a unit direction, `length`
// long from the middle of its base to its tip and `width` wide at its base.
package struct Arrowhead: Equatable, Sendable {
    // MARK: - Property
    package let tip: Point
    package let axis: Point
    package let length: Double
    package let width: Double

    // The middle of its base, where the line it ends stops.
    package var base: Point {
        Point(x: tip.x - axis.x * length, y: tip.y - axis.y * length)
    }

    package var corners: [Point] {
        let across = Point(x: -axis.y * width / 2, y: axis.x * width / 2)
        return [
            Point(x: base.x + across.x, y: base.y + across.y),
            tip,
            Point(x: base.x - across.x, y: base.y - across.y)
        ]
    }

    // MARK: - Initializer
    package init(
        tip: Point,
        axis: Point,
        length: Double,
        width: Double
    ) {
        self.tip = tip
        self.axis = axis
        self.length = length
        self.width = width
    }

    // MARK: - Public
    // MARK: - Private
}

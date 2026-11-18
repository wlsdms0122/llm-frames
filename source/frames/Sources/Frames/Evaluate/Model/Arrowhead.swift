//
//  Arrowhead.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A triangle with its tip at an end of the drawn stroke, pointing along `axis`, a unit direction, `length` long and as
// wide at its base.
package struct Arrowhead: Equatable, Sendable {
    // MARK: - Property
    package let tip: Point
    package let axis: Point
    package let length: Double

    // The middle of its base, where the line it ends stops.
    package var base: Point {
        Point(x: tip.x - axis.x * length, y: tip.y - axis.y * length)
    }

    package var corners: [Point] {
        let across = Point(x: -axis.y * length / 2, y: axis.x * length / 2)
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
        length: Double
    ) {
        self.tip = tip
        self.axis = axis
        self.length = length
    }

    // MARK: - Public
    // MARK: - Private
}

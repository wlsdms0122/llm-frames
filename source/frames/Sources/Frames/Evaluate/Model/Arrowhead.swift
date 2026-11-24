//
//  Arrowhead.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A head drawn at an end of the stroke, its tip at that end, lying along `axis`, a unit direction, from the middle of
// its base `length` back to its tip, and `width` wide across it. `unit` is the stroke's width times the head's scale,
// after shrinking, which a line arrow's bands are thick. Each shape fills that frame as `StrokeEndShape` draws it: on
// a straight end the frame is the shape's length and width in units, and on a curved one `length` is the chord of the
// stroke's last part as long as the head, so its tip and its base both lie on the curve.
package struct Arrowhead: Equatable, Sendable {
    // MARK: - Property
    package let shape: StrokeEndShape
    package let tip: Point
    package let axis: Point
    package let length: Double
    package let width: Double
    package let unit: Double

    // The middle of its base.
    package var base: Point {
        point(back: length, across: 0)
    }

    // The convex polygons the head is the union of, each by its corners in order, a circle's by the square it is
    // inscribed in, which holds it.
    package var parts: [[Point]] {
        let half = width / 2
        switch shape {
        case .none:
            return []

        case .arrow:
            return [triangle]

        case .lineArrow:
            // The inner edges lie `unit` inside the two sides and meet on the axis, where a head too small to hold
            // them is the whole triangle.
            let sine = half / (length * length + half * half).squareRoot()
            let inner = sine > 0 ? unit / sine : .infinity
            guard inner < length else { return [triangle] }

            let reach = (length - inner) * half / length
            let corner = point(back: inner, across: 0)
            return [
                [tip, point(back: length, across: half), point(back: length, across: reach), corner],
                [tip, corner, point(back: length, across: -reach), point(back: length, across: -half)]
            ]

        case .diamond:
            return [[
                tip,
                point(back: length / 2, across: -half),
                point(back: length, across: 0),
                point(back: length / 2, across: half)
            ]]

        case .circle, .square, .bar:
            return [[
                point(back: 0, across: half),
                point(back: 0, across: -half),
                point(back: length, across: -half),
                point(back: length, across: half)
            ]]
        }
    }

    // The circle a circle head is, its diameter its length, touching its tip and its base. Nil for every other shape.
    package var circle: (center: Point, radius: Double)? {
        guard shape == .circle else { return nil }

        return (point(back: length / 2, across: 0), length / 2)
    }

    // MARK: - Initializer
    package init(
        shape: StrokeEndShape,
        tip: Point,
        axis: Point,
        length: Double,
        width: Double,
        unit: Double
    ) {
        self.shape = shape
        self.tip = tip
        self.axis = axis
        self.length = length
        self.width = width
        self.unit = unit
    }

    // MARK: - Public
    // MARK: - Private
    // The arrow's triangle: a corner of its base, its tip and the other corner.
    private var triangle: [Point] {
        [point(back: length, across: width / 2), tip, point(back: length, across: -width / 2)]
    }

    // The point `back` behind the tip along the axis and `across` along the axis turned a quarter turn clockwise in
    // y-down coordinates.
    private func point(
        back: Double,
        across: Double
    ) -> Point {
        Point(
            x: tip.x - axis.x * back - axis.y * across,
            y: tip.y - axis.y * back + axis.x * across
        )
    }
}

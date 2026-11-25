//
//  Arrowhead.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A head drawn at an end of the stroke (FRAMES-20 Arrowheads): its preset's outline laid with its origin at `tip` and
// its x axis along `axis`, a unit direction from the middle of its base to its tip. Each unit of the outline is `along`
// long along the axis and `unit` across it, `unit` the stroke's width times the head's scale after shrinking. On a
// straight end the two are equal, and on a curved one the axis is the chord of the stroke's last part as long as the
// head, and `along` is that chord over the head's length, so its tip and its base both lie on the curve.
package struct Arrowhead: Equatable, Sendable {
    // MARK: - Property
    package let head: StrokeHead
    package let tip: Point
    package let axis: Point
    package let along: Double
    package let unit: Double

    // The map from the head's own coordinates onto the stroke's.
    package var transform: AffineTransform {
        AffineTransform(
            a: axis.x * along,
            b: axis.y * along,
            c: -axis.y * unit,
            d: axis.x * unit,
            tx: tip.x,
            ty: tip.y
        )
    }

    // The head's outline in the stroke's coordinates, a closed path.
    package var geometry: PathGeometry {
        let transform = transform
        return .path(head.outline.map { $0.carried(by: transform) }, isClosed: true)
    }

    // The vertices and control points of its outline in the stroke's coordinates, whose convex hull holds the head.
    package var controlPoints: [Point] {
        let transform = transform
        return head.controlPoints.map(transform.apply(to:))
    }

    // MARK: - Initializer
    package init(
        head: StrokeHead,
        tip: Point,
        axis: Point,
        along: Double,
        unit: Double
    ) {
        self.head = head
        self.tip = tip
        self.axis = axis
        self.along = along
        self.unit = unit
    }

    // MARK: - Public
    // MARK: - Private
}

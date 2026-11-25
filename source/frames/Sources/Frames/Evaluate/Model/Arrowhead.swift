//
//  Arrowhead.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A head drawn at an end of the stroke (FRAMES-20 Arrowheads): its preset's outline turned so its x axis lies along
// `axis`, a unit direction from the middle of its base to its tip, grown by `scale` along both axes and moved so its
// origin is `tip`. `scale` is the chord from its base to its tip over the head's length, so the head keeps its shape on
// every end: on a straight end the chord is the head's length along the stroke and `scale` is the stroke's width times
// the head's scale after shrinking, and on a curved one the chord is shorter.
package struct Arrowhead: Equatable, Sendable {
    // MARK: - Property
    package let head: StrokeHead
    package let tip: Point
    package let axis: Point
    package let scale: Double

    // The map from the head's own coordinates onto the stroke's.
    package var transform: AffineTransform {
        AffineTransform(
            a: axis.x * scale,
            b: axis.y * scale,
            c: -axis.y * scale,
            d: axis.x * scale,
            tx: tip.x,
            ty: tip.y
        )
    }

    // How far back along the stroke from the tip the line stops.
    package var inset: Double {
        head.inset * scale
    }

    // MARK: - Initializer
    package init(
        head: StrokeHead,
        tip: Point,
        axis: Point,
        scale: Double
    ) {
        self.head = head
        self.tip = tip
        self.axis = axis
        self.scale = scale
    }

    // MARK: - Public
    // The head's outline, a closed path, in the stroke's coordinates carried on by `transform`.
    package func geometry(carriedBy transform: AffineTransform = .identity) -> PathGeometry {
        let map = self.transform.concatenating(transform)
        return .path(head.outline.map { $0.carried(by: map) }, isClosed: true)
    }

    // MARK: - Private
}

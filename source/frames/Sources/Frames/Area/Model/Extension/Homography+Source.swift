//
//  Homography+Source.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A point lies in front of the horizon where w has the sign w has inside `source`, the strictly convex quad the
// homography is taken from, and a point where w is 0 does not (FRAMES-27 The homography). No factor of the matrix
// changes the test.
extension Homography {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The point carried, nil when it does not lie in front of the horizon.
    func apply(
        to point: Point,
        inFrontOf source: Quad
    ) -> Point? {
        let inside = w(at: source.centroid)
        let w = self.w(at: point)
        guard inside != 0, w != 0, (w > 0) == (inside > 0) else { return nil }

        return Point(x: (a * point.x + c * point.y + tx) / w, y: (b * point.x + d * point.y + ty) / w)
    }

    // Each corner carried, nil when any corner does not lie in front of the horizon.
    func apply(
        to quad: Quad,
        inFrontOf source: Quad
    ) -> Quad? {
        guard
            let topLeft = apply(to: quad.topLeft, inFrontOf: source),
            let topRight = apply(to: quad.topRight, inFrontOf: source),
            let bottomRight = apply(to: quad.bottomRight, inFrontOf: source),
            let bottomLeft = apply(to: quad.bottomLeft, inFrontOf: source)
        else {
            return nil
        }

        return Quad(topLeft: topLeft, topRight: topRight, bottomRight: bottomRight, bottomLeft: bottomLeft)
    }

    // MARK: - Private
}

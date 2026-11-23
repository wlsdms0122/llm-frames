//
//  PathVertex+Carried.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

// A vertex carried by an affine map: its point by the whole map and its tangents, offsets, by its linear part. An
// affine map takes a cubic Bézier segment to the one through its carried control points, so the carried vertices draw
// the carried curve exactly (FRAMES-10).
extension PathVertex where Location == Point, Offset == Point {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    package func carried(by transform: AffineTransform) -> PathVertex<Point, Point> {
        map(vertex: transform.apply(to:), tangent: transform.apply(toOffset:))
    }

    // MARK: - Private
}

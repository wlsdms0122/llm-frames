//
//  Homography+Source.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

extension Homography {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Each corner carried, nil when any corner does not lie in front of the horizon: a point lies in front where w has
    // the sign w has inside `source`, the strictly convex quad the homography is taken from, and a point where w is 0
    // does not (FRAMES-27 The homography). No factor of the matrix changes the test.
    func apply(
        to quad: Quad,
        inFrontOf source: Quad
    ) -> Quad? {
        let inside = w(at: source.centroid)
        let corners = quad.corners.compactMap { corner -> Point? in
            let w = self.w(at: corner)
            guard w != 0, (w > 0) == (inside > 0) else { return nil }

            return Point(x: (a * corner.x + c * corner.y + tx) / w, y: (b * corner.x + d * corner.y + ty) / w)
        }
        guard inside != 0, corners.count == 4 else { return nil }

        return Quad(topLeft: corners[0], topRight: corners[1], bottomRight: corners[2], bottomLeft: corners[3])
    }

    // MARK: - Private
}

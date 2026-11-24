//
//  Track+CornerPin.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// A keyframe of a tracked corner pin brought back to the track's frame (FRAMES-27 A tracked corner pin), as resolve
// checks it and evaluation draws it. Each corner that is a point, a number or found by text, is brought back through
// the inverse of the homography of the frame shown at its media time, and the keyframe is nil where such a corner does
// not lie in front of that inverse's horizon. A corner of a clip area is the named clip's box before its tracked
// motion, on the track's frame already, and is kept. A keyframe of points only is also nil where its corner pin
// brought back is not strictly convex; one holding a clip area is tested where it draws, since only evaluation knows
// the named clip's box.
extension Track {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func broughtBack(
        _ cornerPin: GeometryQuad,
        atMediaTime time: Double
    ) -> GeometryQuad? {
        guard let homography = homography(atMediaTime: time), let frame = homography.apply(to: target) else {
            return nil
        }

        let inverse = homography.inverse
        let corners = cornerPin.corners.compactMap { corner -> GeometryPoint? in
            guard case let .point(point) = corner else { return corner }

            return inverse.apply(to: point, inFrontOf: frame).map(GeometryPoint.point)
        }
        guard corners.count == 4 else { return nil }

        let broughtBack = GeometryQuad(corners: corners)
        if let quad = broughtBack.fixed, !quad.isStrictlyConvex {
            return nil
        }

        return broughtBack
    }

    // MARK: - Private
}

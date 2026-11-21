//
//  Track+CornerPin.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// A keyframe of a tracked corner pin brought back to the track's frame (FRAMES-27 A tracked corner pin), as resolve
// checks it and evaluation draws it. A keyframe whose points are all numbers is brought back through the inverse of the
// homography of the frame shown at its media time, corner by corner, nil where a corner does not lie wholly in front
// of that inverse's horizon or the corner pin brought back is not strictly convex. A keyframe holding a clip area is
// the named clip's box at each instant, sampled where it is read, and is not brought back.
extension Track {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func broughtBack(
        _ cornerPin: [GeometryPoint],
        atMediaTime time: Double
    ) -> [GeometryPoint]? {
        guard cornerPin.count == 4, cornerPin.allSatisfy({ $0.clipArea == nil }) else { return cornerPin }

        let corners = cornerPin.map(\.fixed)
        let pin = Quad(topLeft: corners[0], topRight: corners[1], bottomRight: corners[2], bottomLeft: corners[3])
        guard
            let homography = homography(atMediaTime: time),
            let frame = homography.apply(to: target),
            let broughtBack = homography.inverse.apply(to: pin, inFrontOf: frame),
            broughtBack.isStrictlyConvex
        else {
            return nil
        }

        return broughtBack.corners.map(GeometryPoint.point)
    }

    // MARK: - Private
}

//
//  Quad+CornerPin.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

extension Quad {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Whether the quad is a corner pin a display list holds: strictly convex, so the homography that carries a picture
    // onto it takes `dest` onto its inside without passing through infinity, or in a sample list also four points at
    // [0, 0], where a clip's group draws nothing (FRAMES-20 Pictures, FRAMES-27).
    package func isCornerPin(inSampleList isInSampleList: Bool) -> Bool {
        isStrictlyConvex || (isInSampleList && self == .collapsed)
    }

    // MARK: - Private
}

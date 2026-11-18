//
//  TargetFacing.swift
//  FramesPointTracker
//
//  Created by JSilver on 11/18/26.
//

import Foundation
import Frames

// How a target's quad faces on its own frame: its centroid, the angle of its top edge in radians, clockwise positive
// in y-down pixels, and its width and height, the means of its opposite sides. The track points and their features
// are laid out in these axes, so a target given turned is read as it faces.
struct TargetFacing: Sendable {
    // MARK: - Property
    let centre: CGPoint
    let angle: Double
    let width: Double
    let height: Double

    // MARK: - Initializer
    init(_ quad: Quad) {
        let top = Point(x: quad.topRight.x - quad.topLeft.x, y: quad.topRight.y - quad.topLeft.y)
        let bottom = Point(x: quad.bottomRight.x - quad.bottomLeft.x, y: quad.bottomRight.y - quad.bottomLeft.y)
        let centroid = quad.centroid

        self.centre = CGPoint(x: centroid.x, y: centroid.y)
        self.angle = atan2(top.y + bottom.y, top.x + bottom.x)
        self.width = (hypot(top.x, top.y) + hypot(bottom.x, bottom.y)) / 2
        self.height = (
            hypot(quad.bottomLeft.x - quad.topLeft.x, quad.bottomLeft.y - quad.topLeft.y)
                + hypot(quad.bottomRight.x - quad.topRight.x, quad.bottomRight.y - quad.topRight.y)
        ) / 2
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  PlanePose.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/22/26.
//

import Foundation
import Frames

// Where a flat poster stands before a pinhole camera: its centre at (`x`, `y`, `distance`) in camera coordinates, x to
// the right, y down and z along the view, in the poster's own pixels, and turned by `yaw` about its vertical axis,
// then `pitch` about its horizontal axis, then `roll` about the view, in degrees.
package struct PlanePose: Sendable {
    // MARK: - Property
    package let x: Double
    package let y: Double
    package let distance: Double
    package let yaw: Double
    package let pitch: Double
    package let roll: Double

    // MARK: - Initializer
    package init(
        x: Double = 0,
        y: Double = 0,
        distance: Double,
        yaw: Double = 0,
        pitch: Double = 0,
        roll: Double = 0
    ) {
        self.x = x
        self.y = y
        self.distance = distance
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
    }

    // MARK: - Public
    // The corners of a poster of `size` on a picture of `frame` taken with a focal length of `focal` pixels, the axis
    // of view through the picture's centre.
    package func corners(
        of size: Size,
        focal: Double,
        on frame: Size
    ) -> Quad {
        let corners = [(0.0, 0.0), (size.width, 0), (size.width, size.height), (0, size.height)].map { u, v in
            projected(u - size.width / 2, v - size.height / 2, focal: focal, frame: frame)
        }

        return Quad(topLeft: corners[0], topRight: corners[1], bottomRight: corners[2], bottomLeft: corners[3])
    }

    // MARK: - Private
    // The point (`u`, `v`) of the poster from its centre, turned as Rz(roll) Ry(yaw) Rx(pitch) and projected.
    private func projected(
        _ u: Double,
        _ v: Double,
        focal: Double,
        frame: Size
    ) -> Point {
        let (yawSine, yawCosine) = (sin(yaw * .pi / 180), cos(yaw * .pi / 180))
        let (pitchSine, pitchCosine) = (sin(pitch * .pi / 180), cos(pitch * .pi / 180))
        let (rollSine, rollCosine) = (sin(roll * .pi / 180), cos(roll * .pi / 180))
        let pitched = (x: u, y: v * pitchCosine, z: v * pitchSine)
        let yawed = (
            x: pitched.x * yawCosine + pitched.z * yawSine,
            y: pitched.y,
            z: -pitched.x * yawSine + pitched.z * yawCosine
        )
        let rolled = (x: yawed.x * rollCosine - yawed.y * rollSine, y: yawed.x * rollSine + yawed.y * rollCosine)
        let depth = distance + yawed.z

        return Point(
            x: frame.width / 2 + focal * (x + rolled.x) / depth,
            y: frame.height / 2 + focal * (y + rolled.y) / depth
        )
    }
}

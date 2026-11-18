//
//  OutlineSegment+Path.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Frames

// A piece of an outline added to a Core Graphics path.
extension OutlineSegment {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Adds the piece between two distances to a path whose current point is already at the first.
    func append(
        from start: Double,
        to end: Double,
        to path: CGMutablePath
    ) {
        switch self {
        case .line:
            let last = point(at: end)
            path.addLine(to: CGPoint(x: last.x, y: last.y))

        case let .arc(center, radii, angle, _):
            // The unit circle carried onto the ellipse, so its angles are the ellipse's parameter.
            path.addArc(
                center: .zero,
                radius: 1,
                startAngle: angle + self.angle(at: start),
                endAngle: angle + self.angle(at: end),
                clockwise: false,
                transform: CGAffineTransform(a: radii.width, b: 0, c: 0, d: radii.height, tx: center.x, ty: center.y)
            )
        }
    }

    // MARK: - Private
}

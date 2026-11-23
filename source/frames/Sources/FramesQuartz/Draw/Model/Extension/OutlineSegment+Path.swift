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

        case let .arc(center, xAxis, yAxis, angle, _):
            // The unit circle carried onto the ellipse, so its angles are the ellipse's parameter.
            path.addArc(
                center: .zero,
                radius: 1,
                startAngle: angle + self.angle(at: start),
                endAngle: angle + self.angle(at: end),
                clockwise: false,
                transform: CGAffineTransform(a: xAxis.x, b: xAxis.y, c: yAxis.x, d: yAxis.y, tx: center.x, ty: center.y)
            )

        case .cubic:
            guard case let .cubic(_, first, second, last) = piece(from: start, to: end) else { return }

            path.addCurve(
                to: CGPoint(x: last.x, y: last.y),
                control1: CGPoint(x: first.x, y: first.y),
                control2: CGPoint(x: second.x, y: second.y)
            )
        }
    }

    // MARK: - Private
}

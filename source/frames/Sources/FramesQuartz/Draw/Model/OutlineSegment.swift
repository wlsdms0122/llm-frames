//
//  OutlineSegment.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Foundation

// A piece of an outline: a straight edge, or a part of the ellipse about `center` whose points are
// `center + (radii.width × cos θ, radii.height × sin θ)` for θ from `start` through `sweep`. A growing θ turns clockwise
// in y-down coordinates. Distances are measured along the piece from its start.
enum OutlineSegment {
    case line(from: CGPoint, to: CGPoint)
    case arc(center: CGPoint, radii: CGSize, start: CGFloat, sweep: CGFloat)

    // MARK: - Property
    // Steps of Simpson's rule over a whole sweep of an elliptical arc.
    private static let steps = 256

    var isLine: Bool {
        guard case .line = self else { return false }

        return true
    }

    var length: CGFloat {
        switch self {
        case let .line(from, to):
            hypot(to.x - from.x, to.y - from.y)

        case let .arc(_, _, _, sweep):
            arcLength(through: sweep)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    func point(at distance: CGFloat) -> CGPoint {
        switch self {
        case let .line(from, to):
            let progress = length > 0 ? distance / length : 0
            return CGPoint(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress)

        case let .arc(center, radii, start, _):
            let angle = start + angle(at: distance)
            return CGPoint(x: center.x + radii.width * cos(angle), y: center.y + radii.height * sin(angle))
        }
    }

    // The unit direction of travel at a distance.
    func direction(at distance: CGFloat) -> CGPoint {
        let vector: CGPoint
        switch self {
        case let .line(from, to):
            vector = CGPoint(x: to.x - from.x, y: to.y - from.y)

        case let .arc(_, radii, start, _):
            let angle = start + angle(at: distance)
            vector = CGPoint(x: -radii.width * sin(angle), y: radii.height * cos(angle))
        }
        let size = hypot(vector.x, vector.y)

        return size > 0 ? CGPoint(x: vector.x / size, y: vector.y / size) : .zero
    }

    // Adds the piece between two distances to a path whose current point is already at the first.
    func append(
        from start: CGFloat,
        to end: CGFloat,
        to path: CGMutablePath
    ) {
        switch self {
        case .line:
            path.addLine(to: point(at: end))

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
    // The parameter past `start` where the arc has run a distance, exact for a circle and found by halving for an
    // ellipse, whose length grows with its parameter.
    private func angle(at distance: CGFloat) -> CGFloat {
        guard case let .arc(_, radii, _, sweep) = self else { return 0 }
        guard radii.width != radii.height else { return radii.width > 0 ? distance / radii.width : 0 }

        var low: CGFloat = 0
        var high = sweep
        for _ in 0..<40 {
            let middle = (low + high) / 2
            if arcLength(through: middle) < distance { low = middle } else { high = middle }
        }

        return (low + high) / 2
    }

    // The length from `start` through a part of the sweep, by Simpson's rule.
    private func arcLength(through part: CGFloat) -> CGFloat {
        guard case let .arc(_, radii, start, sweep) = self else { return 0 }
        guard radii.width != radii.height else { return radii.width * part }

        let steps = max(2, Int((CGFloat(Self.steps) * part / sweep).rounded(.up)) & ~1)
        let step = part / CGFloat(steps)
        let speed = { (angle: CGFloat) in hypot(radii.width * sin(start + angle), radii.height * cos(start + angle)) }

        let sum = (0...steps).reduce(CGFloat(0)) { sum, index in
            let weight: CGFloat = index == 0 || index == steps ? 1 : (index % 2 == 1 ? 4 : 2)
            return sum + weight * speed(CGFloat(index) * step)
        }

        return sum * step / 3
    }
}

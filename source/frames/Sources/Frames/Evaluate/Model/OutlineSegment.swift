//
//  OutlineSegment.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// A piece of an outline: a straight edge, or a part of the ellipse about `center` whose points are
// `center + (radii.width × cos θ, radii.height × sin θ)` for θ from `start` through `sweep`. A growing θ turns clockwise
// in y-down coordinates. Distances are measured along the piece from its start.
package enum OutlineSegment: Equatable, Sendable {
    case line(from: Point, to: Point)
    case arc(center: Point, radii: Size, start: Double, sweep: Double)

    // MARK: - Property
    // Steps of Simpson's rule over a whole sweep of an elliptical arc.
    private static let steps = 256

    package var isLine: Bool {
        guard case .line = self else { return false }

        return true
    }

    package var length: Double {
        switch self {
        case let .line(from, to):
            hypot(to.x - from.x, to.y - from.y)

        case let .arc(_, _, _, sweep):
            arcLength(through: sweep)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    package func point(at distance: Double) -> Point {
        switch self {
        case let .line(from, to):
            let progress = length > 0 ? distance / length : 0
            return Point(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress)

        case let .arc(center, radii, start, _):
            let angle = start + angle(at: distance)
            return Point(x: center.x + radii.width * cos(angle), y: center.y + radii.height * sin(angle))
        }
    }

    // The unit direction of travel at a distance.
    package func direction(at distance: Double) -> Point {
        let vector: Point
        switch self {
        case let .line(from, to):
            vector = Point(x: to.x - from.x, y: to.y - from.y)

        case let .arc(_, radii, start, _):
            let angle = start + angle(at: distance)
            vector = Point(x: -radii.width * sin(angle), y: radii.height * cos(angle))
        }
        let size = hypot(vector.x, vector.y)

        return size > 0 ? Point(x: vector.x / size, y: vector.y / size) : Point(x: 0, y: 0)
    }

    // The parameter past `start` where the arc has run a distance, exact for a circle and found by halving for an
    // ellipse, whose length grows with its parameter. A line has none.
    package func angle(at distance: Double) -> Double {
        guard case let .arc(_, radii, _, sweep) = self else { return 0 }
        guard radii.width != radii.height else { return radii.width > 0 ? distance / radii.width : 0 }

        var low = 0.0
        var high = sweep
        for _ in 0..<40 {
            let middle = (low + high) / 2
            if arcLength(through: middle) < distance { low = middle } else { high = middle }
        }

        return (low + high) / 2
    }

    // MARK: - Private
    // The length from `start` through a part of the sweep, by Simpson's rule.
    private func arcLength(through part: Double) -> Double {
        guard case let .arc(_, radii, start, sweep) = self else { return 0 }
        guard radii.width != radii.height else { return radii.width * part }

        let steps = max(2, Int((Double(Self.steps) * part / sweep).rounded(.up)) & ~1)
        let step = part / Double(steps)
        let speed = { (angle: Double) in hypot(radii.width * sin(start + angle), radii.height * cos(start + angle)) }

        let sum = (0...steps).reduce(0.0) { sum, index in
            let weight: Double = index == 0 || index == steps ? 1 : (index % 2 == 1 ? 4 : 2)
            return sum + weight * speed(Double(index) * step)
        }

        return sum * step / 3
    }
}

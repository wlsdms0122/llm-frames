//
//  OutlineSegment.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// A piece of an outline: a straight edge, or a part of the ellipse about `center` whose points are
// `center + xAxis × cos θ + yAxis × sin θ` for θ from `start` through `sweep`, the unit circle carried by the linear map
// that takes its axes to `xAxis` and `yAxis`. With the axes along x and y a growing θ turns clockwise in y-down
// coordinates. Distances are measured along the piece from its start.
package enum OutlineSegment: Equatable, Sendable {
    case line(from: Point, to: Point)
    case arc(center: Point, xAxis: Point, yAxis: Point, start: Double, sweep: Double)

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

        case let .arc(_, _, _, _, sweep):
            distance(atAngle: sweep)
        }
    }

    // MARK: - Initializer
    // The part of the axis-aligned ellipse of `radii` about `center`.
    package static func arc(
        center: Point,
        radii: Size,
        start: Double,
        sweep: Double
    ) -> OutlineSegment {
        .arc(
            center: center,
            xAxis: Point(x: radii.width, y: 0),
            yAxis: Point(x: 0, y: radii.height),
            start: start,
            sweep: sweep
        )
    }

    // MARK: - Public
    // The piece carried by an affine map, its parameter kept: the same θ on both is the same point carried.
    package func carried(by transform: AffineTransform) -> OutlineSegment {
        switch self {
        case let .line(from, to):
            return .line(from: transform.apply(to: from), to: transform.apply(to: to))

        case let .arc(center, xAxis, yAxis, start, sweep):
            let linear = { (vector: Point) in
                Point(x: transform.a * vector.x + transform.c * vector.y, y: transform.b * vector.x + transform.d * vector.y)
            }
            return .arc(
                center: transform.apply(to: center),
                xAxis: linear(xAxis),
                yAxis: linear(yAxis),
                start: start,
                sweep: sweep
            )
        }
    }

    // The distance along this piece to where `other`, the same piece carried, has run `distance`.
    package func distance(
        _ distance: Double,
        from other: OutlineSegment
    ) -> Double {
        switch self {
        case .line:
            other.length > 0 ? distance / other.length * length : 0

        case .arc:
            self.distance(atAngle: other.angle(at: distance))
        }
    }

    package func point(at distance: Double) -> Point {
        switch self {
        case let .line(from, to):
            let progress = length > 0 ? distance / length : 0
            return Point(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress)

        case let .arc(center, xAxis, yAxis, start, _):
            let angle = start + angle(at: distance)
            return Point(
                x: center.x + xAxis.x * cos(angle) + yAxis.x * sin(angle),
                y: center.y + xAxis.y * cos(angle) + yAxis.y * sin(angle)
            )
        }
    }

    // The unit direction of travel at a distance.
    package func direction(at distance: Double) -> Point {
        let vector: Point
        switch self {
        case let .line(from, to):
            vector = Point(x: to.x - from.x, y: to.y - from.y)

        case let .arc(_, xAxis, yAxis, start, _):
            vector = velocity(at: start + angle(at: distance), xAxis: xAxis, yAxis: yAxis)
        }
        let size = hypot(vector.x, vector.y)

        return size > 0 ? Point(x: vector.x / size, y: vector.y / size) : Point(x: 0, y: 0)
    }

    // The parameter past `start` where the arc has run a distance, exact for a circle and found by halving for an
    // ellipse, whose length grows with its parameter. A line has none.
    package func angle(at distance: Double) -> Double {
        guard case let .arc(_, _, _, _, sweep) = self else { return 0 }
        if let radius { return radius > 0 ? distance / radius : 0 }

        var low = 0.0
        var high = sweep
        for _ in 0..<40 {
            let middle = (low + high) / 2
            if self.distance(atAngle: middle) < distance { low = middle } else { high = middle }
        }

        return (low + high) / 2
    }

    // The length from `start` through a part of the sweep, exact for a circle and by Simpson's rule for an ellipse.
    package func distance(atAngle part: Double) -> Double {
        guard case let .arc(_, xAxis, yAxis, start, sweep) = self else { return 0 }
        if let radius { return radius * part }

        let steps = max(2, Int((Double(Self.steps) * part / sweep).rounded(.up)) & ~1)
        let step = part / Double(steps)
        let speed = { (angle: Double) in
            let velocity = velocity(at: start + angle, xAxis: xAxis, yAxis: yAxis)
            return hypot(velocity.x, velocity.y)
        }

        let sum = (0...steps).reduce(0.0) { sum, index in
            let weight: Double = index == 0 || index == steps ? 1 : (index % 2 == 1 ? 4 : 2)
            return sum + weight * speed(Double(index) * step)
        }

        return sum * step / 3
    }

    // MARK: - Private
    // The radius of an arc of a circle, whose axes are as long as each other and at right angles, and nil otherwise.
    private var radius: Double? {
        guard case let .arc(_, xAxis, yAxis, _, _) = self else { return nil }

        let size = hypot(xAxis.x, xAxis.y)
        guard size == hypot(yAxis.x, yAxis.y), xAxis.x * yAxis.x + xAxis.y * yAxis.y == 0 else { return nil }

        return size
    }

    private func velocity(
        at angle: Double,
        xAxis: Point,
        yAxis: Point
    ) -> Point {
        Point(x: -xAxis.x * sin(angle) + yAxis.x * cos(angle), y: -xAxis.y * sin(angle) + yAxis.y * cos(angle))
    }
}

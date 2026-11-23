//
//  OutlineSegment.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// A piece of an outline: a straight edge, a part of the ellipse about `center` whose points are
// `center + xAxis × cos θ + yAxis × sin θ` for θ from `start` through `sweep`, the unit circle carried by the linear map
// that takes its axes to `xAxis` and `yAxis`, or the cubic Bézier curve from `from` to `to` with the control points
// `first` and `second`, whose parameter t runs from 0 to 1. With the axes along x and y a growing θ turns clockwise in
// y-down coordinates. Distances are measured along the piece from its start, along a curve by its arc length.
package enum OutlineSegment: Equatable, Sendable {
    case line(from: Point, to: Point)
    case arc(center: Point, xAxis: Point, yAxis: Point, start: Double, sweep: Double)
    case cubic(from: Point, first: Point, second: Point, to: Point)

    // MARK: - Property
    // Steps of Simpson's rule over a whole sweep of an elliptical arc and over a whole cubic.
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

        case .cubic:
            distance(atParameter: 1)
        }
    }

    // The points strictly inside a cubic where its velocity is 0 and its direction turns back, its cusps, each with its
    // distance and the direction it leaves by, that of its acceleration there. A line and an arc have none.
    package var cusps: [(distance: Double, point: Point, leaving: Point)] {
        guard case let .cubic(from, first, second, to) = self else { return [] }

        // A cusp is a root of both coordinates' derivatives. Where one has a double root there, rounding moves it by
        // about the square root of the precision, so a root of either counts where the velocity is that close to 0.
        let roots = (Self.roots(ofDerivative: from.x, first.x, second.x, to.x) ?? [])
            + (Self.roots(ofDerivative: from.y, first.y, second.y, to.y) ?? [])
        let scale = [first, second, to].map { abs($0.x - from.x) + abs($0.y - from.y) }.max() ?? 0
        let isStill = { (parameter: Double) in
            let velocity = Self.velocity(at: parameter, from, first, second, to)
            return abs(velocity.x) + abs(velocity.y) <= 1e-6 * scale
        }
        let found = roots.filter { parameter in parameter > 0 && parameter < 1 && isStill(parameter) }.sorted()
        let distinct = found.enumerated().filter { index, parameter in index == 0 || parameter - found[index - 1] > 1e-6 }

        return distinct.map { _, parameter in
            let acceleration = Self.acceleration(at: parameter, from, first, second, to)
            let size = hypot(acceleration.x, acceleration.y)
            return (
                distance(atParameter: parameter),
                Self.point(at: parameter, from, first, second, to),
                size > 0 ? Point(x: acceleration.x / size, y: acceleration.y / size) : Point(x: 0, y: 0)
            )
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

    // The segment of a path from one vertex to the next (FRAMES-11 Paths): straight where both tangents that shape it
    // are 0, and otherwise the cubic through the first vertex plus its out tangent and the next plus its in tangent.
    static func joining(
        _ start: PathVertex<Point, Point>,
        _ end: PathVertex<Point, Point>
    ) -> OutlineSegment {
        let zero = Point(x: 0, y: 0)
        guard start.outTangent != zero || end.inTangent != zero else { return .line(from: start.vertex, to: end.vertex) }

        return .cubic(
            from: start.vertex,
            first: Point(x: start.vertex.x + start.outTangent.x, y: start.vertex.y + start.outTangent.y),
            second: Point(x: end.vertex.x + end.inTangent.x, y: end.vertex.y + end.inTangent.y),
            to: end.vertex
        )
    }

    // MARK: - Public
    // The piece carried by an affine map, its parameter kept: the same θ or t on both is the same point carried.
    package func carried(by transform: AffineTransform) -> OutlineSegment {
        switch self {
        case let .line(from, to):
            .line(from: transform.apply(to: from), to: transform.apply(to: to))

        case let .arc(center, xAxis, yAxis, start, sweep):
            .arc(
                center: transform.apply(to: center),
                xAxis: transform.apply(toOffset: xAxis),
                yAxis: transform.apply(toOffset: yAxis),
                start: start,
                sweep: sweep
            )

        case let .cubic(from, first, second, to):
            .cubic(
                from: transform.apply(to: from),
                first: transform.apply(to: first),
                second: transform.apply(to: second),
                to: transform.apply(to: to)
            )
        }
    }

    // The part of this piece between two distances along it, a piece of the same kind: a cubic's by de Casteljau's
    // split at the parameters of the two distances.
    package func piece(
        from start: Double,
        to end: Double
    ) -> OutlineSegment {
        switch self {
        case .line:
            return .line(from: point(at: start), to: point(at: end))

        case let .arc(center, xAxis, yAxis, angle, _):
            let low = self.angle(at: start)
            return .arc(center: center, xAxis: xAxis, yAxis: yAxis, start: angle + low, sweep: self.angle(at: end) - low)

        case let .cubic(from, first, second, to):
            let low = parameter(at: start)
            let high = parameter(at: end)
            let head = Self.split(from, first, second, to, at: high).head
            let tail = Self.split(head.0, head.1, head.2, head.3, at: high > 0 ? low / high : 0).tail
            return .cubic(from: tail.0, first: tail.1, second: tail.2, to: tail.3)
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

        case .cubic:
            self.distance(atParameter: other.parameter(at: distance))
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

        case let .cubic(from, first, second, to):
            return Self.point(at: parameter(at: distance), from, first, second, to)
        }
    }

    // The unit direction of travel at a distance. At a cubic's ends it is the limit (FRAMES-20 Direction at a point):
    // from its start to the first later control point that differs from it, and into its end from the last earlier one
    // that differs. Where its velocity is 0 inside it, at a cusp, it is that of its acceleration, the direction it leaves
    // by.
    package func direction(at distance: Double) -> Point {
        let vector: Point
        switch self {
        case let .line(from, to):
            vector = Point(x: to.x - from.x, y: to.y - from.y)

        case let .arc(_, xAxis, yAxis, start, _):
            vector = velocity(at: start + angle(at: distance), xAxis: xAxis, yAxis: yAxis)

        case let .cubic(from, first, second, to):
            let parameter = parameter(at: distance)
            if parameter <= 0 {
                let next = [first, second, to].first { $0 != from } ?? from
                vector = Point(x: next.x - from.x, y: next.y - from.y)
            } else if parameter >= 1 {
                let previous = [second, first, from].first { $0 != to } ?? to
                vector = Point(x: to.x - previous.x, y: to.y - previous.y)
            } else {
                let velocity = Self.velocity(at: parameter, from, first, second, to)
                vector = velocity != Point(x: 0, y: 0)
                    ? velocity
                    : Self.acceleration(at: parameter, from, first, second, to)
            }
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

        return Self.integral(over: part, of: sweep) { angle in
            let velocity = velocity(at: start + angle, xAxis: xAxis, yAxis: yAxis)
            return hypot(velocity.x, velocity.y)
        }
    }

    // The parameter of a cubic where it has run a distance, found by halving, since its length grows with its
    // parameter. A line and an arc have none.
    package func parameter(at distance: Double) -> Double {
        guard case .cubic = self else { return 0 }
        guard distance > 0 else { return 0 }
        guard distance < length else { return 1 }

        var low = 0.0
        var high = 1.0
        for _ in 0..<50 {
            let middle = (low + high) / 2
            if self.distance(atParameter: middle) < distance { low = middle } else { high = middle }
        }

        return (low + high) / 2
    }

    // The length of a cubic from its start to a parameter, by Simpson's rule.
    package func distance(atParameter parameter: Double) -> Double {
        guard case let .cubic(from, first, second, to) = self, parameter > 0 else { return 0 }

        return Self.integral(over: min(parameter, 1), of: 1) { parameter in
            let velocity = Self.velocity(at: parameter, from, first, second, to)
            return hypot(velocity.x, velocity.y)
        }
    }

    // MARK: - Private
    // Simpson's rule for the integral of `speed` from 0 to `part`, with steps in proportion to the part of `whole`.
    private static func integral(
        over part: Double,
        of whole: Double,
        speed: (Double) -> Double
    ) -> Double {
        let steps = max(2, Int((Double(Self.steps) * part / whole).rounded(.up)) & ~1)
        let step = part / Double(steps)
        let sum = (0...steps).reduce(0.0) { sum, index in
            let weight: Double = index == 0 || index == steps ? 1 : (index % 2 == 1 ? 4 : 2)
            return sum + weight * speed(Double(index) * step)
        }

        return sum * step / 3
    }

    private static func point(
        at t: Double,
        _ from: Point,
        _ first: Point,
        _ second: Point,
        _ to: Point
    ) -> Point {
        let rest = 1 - t
        let weights = (rest * rest * rest, 3 * rest * rest * t, 3 * rest * t * t, t * t * t)
        return Point(
            x: weights.0 * from.x + weights.1 * first.x + weights.2 * second.x + weights.3 * to.x,
            y: weights.0 * from.y + weights.1 * first.y + weights.2 * second.y + weights.3 * to.y
        )
    }

    private static func velocity(
        at t: Double,
        _ from: Point,
        _ first: Point,
        _ second: Point,
        _ to: Point
    ) -> Point {
        let rest = 1 - t
        let weights = (3 * rest * rest, 6 * rest * t, 3 * t * t)
        return Point(
            x: weights.0 * (first.x - from.x) + weights.1 * (second.x - first.x) + weights.2 * (to.x - second.x),
            y: weights.0 * (first.y - from.y) + weights.1 * (second.y - first.y) + weights.2 * (to.y - second.y)
        )
    }

    private static func acceleration(
        at t: Double,
        _ from: Point,
        _ first: Point,
        _ second: Point,
        _ to: Point
    ) -> Point {
        let rest = 1 - t
        return Point(
            x: 6 * rest * (second.x - 2 * first.x + from.x) + 6 * t * (to.x - 2 * second.x + first.x),
            y: 6 * rest * (second.y - 2 * first.y + from.y) + 6 * t * (to.y - 2 * second.y + first.y)
        )
    }

    // The two halves of a cubic split at a parameter, by de Casteljau's construction.
    private static func split(
        _ from: Point,
        _ first: Point,
        _ second: Point,
        _ to: Point,
        at t: Double
    ) -> (head: (Point, Point, Point, Point), tail: (Point, Point, Point, Point)) {
        let between = { (start: Point, end: Point) in Point.interpolate(from: start, to: end, progress: t) }
        let a = between(from, first)
        let b = between(first, second)
        let c = between(second, to)
        let d = between(a, b)
        let e = between(b, c)
        let middle = between(d, e)

        return ((from, a, d, middle), (middle, e, c, to))
    }

    // The parameters where the derivative of the cubic of these coordinates is 0, which is 3 times a t² + b t + c, and
    // nil where it is 0 everywhere, a coordinate that holds still.
    private static func roots(
        ofDerivative start: Double,
        _ first: Double,
        _ second: Double,
        _ end: Double
    ) -> [Double]? {
        let a = -start + 3 * first - 3 * second + end
        let b = 2 * (start - 2 * first + second)
        let c = first - start
        let scale = max(abs(a), abs(b), abs(c))
        guard scale > 0 else { return nil }
        guard abs(a) > 1e-12 * scale else { return abs(b) > 1e-12 * scale ? [-c / b] : [] }

        let discriminant = b * b - 4 * a * c
        // A double root, where a cusp's coordinate turns, may come out a little below 0.
        guard discriminant >= -1e-12 * b * b else { return [] }

        let root = max(discriminant, 0).squareRoot()
        return [(-b + root) / (2 * a), (-b - root) / (2 * a)]
    }

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

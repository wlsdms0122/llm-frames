//
//  Array+PathBounds.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

// The bounding box of a path's outline (FRAMES-11 Paths), the curve its segments draw and not their control points.
// On a cubic segment each coordinate's extremes lie at its ends or where its derivative, a quadratic, is 0, so the box
// is exact. An open path has no closing segment, and the straight one its fill closes it with lies between two of its
// vertices, inside the box.
extension Array where Element == PathVertex<Point, Point> {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func bounds(isClosed: Bool) -> Rectangle {
        let ends = indices.dropLast(isClosed ? 0 : 1).map { index in (self[index], self[(index + 1) % count]) }
        let extremes = ends.flatMap { start, end in
            Self.extremes(
                from: start.vertex,
                Point(x: start.vertex.x + start.outTangent.x, y: start.vertex.y + start.outTangent.y),
                Point(x: end.vertex.x + end.inTangent.x, y: end.vertex.y + end.inTangent.y),
                to: end.vertex
            )
        }

        return Rectangle(bounding: map(\.vertex) + extremes)
    }

    // MARK: - Private
    // The points of a cubic segment inside it where its x or its y turns.
    private static func extremes(
        from start: Point,
        _ first: Point,
        _ second: Point,
        to end: Point
    ) -> [Point] {
        let turns = roots(start.x, first.x, second.x, end.x) + roots(start.y, first.y, second.y, end.y)
        return turns.map { t in
            let rest = 1 - t
            let weights = (rest * rest * rest, 3 * rest * rest * t, 3 * rest * t * t, t * t * t)
            return Point(
                x: weights.0 * start.x + weights.1 * first.x + weights.2 * second.x + weights.3 * end.x,
                y: weights.0 * start.y + weights.1 * first.y + weights.2 * second.y + weights.3 * end.y
            )
        }
    }

    // The parameters strictly between 0 and 1 where the derivative of the cubic of these coordinates is 0. The
    // derivative is 3 times a t² + b t + c.
    private static func roots(
        _ start: Double,
        _ first: Double,
        _ second: Double,
        _ end: Double
    ) -> [Double] {
        let a = -start + 3 * first - 3 * second + end
        let b = 2 * (start - 2 * first + second)
        let c = first - start
        let found: [Double]
        if abs(a) < 1e-12 {
            found = abs(b) < 1e-12 ? [] : [-c / b]
        } else {
            let discriminant = b * b - 4 * a * c
            if discriminant < 0 {
                found = []
            } else {
                let root = discriminant.squareRoot()
                found = [(-b + root) / (2 * a), (-b - root) / (2 * a)]
            }
        }

        return found.filter { $0 > 0 && $0 < 1 }
    }
}

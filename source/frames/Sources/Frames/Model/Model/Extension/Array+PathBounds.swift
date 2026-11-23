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
    // The points of a cubic segment strictly inside it where its x or its y turns.
    private static func extremes(
        from start: Point,
        _ first: Point,
        _ second: Point,
        to end: Point
    ) -> [Point] {
        let x = CubicCoordinate(start.x, first.x, second.x, end.x)
        let y = CubicCoordinate(start.y, first.y, second.y, end.y)
        let turns = ((x.turns ?? []) + (y.turns ?? [])).filter { $0 > 0 && $0 < 1 }

        return turns.map { t in Point(x: x.value(at: t), y: y.value(at: t)) }
    }
}

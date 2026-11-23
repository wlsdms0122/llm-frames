//
//  OutlineSegment+Hull.swift
//  Frames
//
//  Created by JSilver on 11/23/26.
//

extension OutlineSegment {
    // MARK: - Property
    // Points whose convex hull holds the segment: a line's ends, a cubic's control points and the corners of the box
    // of an arc's whole ellipse.
    var hullPoints: [Point] {
        switch self {
        case let .line(from, to):
            return [from, to]

        case let .cubic(from, first, second, to):
            return [from, first, second, to]

        case let .arc(center, xAxis, yAxis, _, _):
            let reach = Point(x: abs(xAxis.x) + abs(yAxis.x), y: abs(xAxis.y) + abs(yAxis.y))

            return [(-1.0, -1.0), (1, -1), (1, 1), (-1, 1)].map { x, y in
                Point(x: center.x + x * reach.x, y: center.y + y * reach.y)
            }
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

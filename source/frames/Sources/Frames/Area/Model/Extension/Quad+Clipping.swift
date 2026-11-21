//
//  Quad+Clipping.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

extension Quad {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func isInside(_ rectangle: Rectangle) -> Bool {
        corners.allSatisfy { corner in
            rectangle.x <= corner.x && corner.x <= rectangle.maxX && rectangle.y <= corner.y && corner.y <= rectangle.maxY
        }
    }

    // The rectangle that bounds the part of the quad inside `rectangle`, nil when no part with area lies inside. The
    // quad is cut by each of the rectangle's four edges in turn.
    func bounds(inside rectangle: Rectangle) -> Rectangle? {
        var polygon = corners
        let edges: [(Point) -> Double] = [
            { $0.x - rectangle.x },
            { rectangle.maxX - $0.x },
            { $0.y - rectangle.y },
            { rectangle.maxY - $0.y }
        ]
        for inside in edges {
            polygon = Self.cut(polygon, keeping: inside)
        }
        guard
            let left = polygon.map(\.x).min(),
            let right = polygon.map(\.x).max(),
            let top = polygon.map(\.y).min(),
            let bottom = polygon.map(\.y).max(),
            left < right,
            top < bottom
        else {
            return nil
        }

        return Rectangle(x: left, y: top, width: right - left, height: bottom - top)
    }

    // MARK: - Private
    // The part of a convex polygon where `inside` is 0 or more, by Sutherland and Hodgman.
    private static func cut(
        _ polygon: [Point],
        keeping inside: (Point) -> Double
    ) -> [Point] {
        var kept: [Point] = []
        for (index, point) in polygon.enumerated() {
            let next = polygon[(index + 1) % polygon.count]
            let distance = inside(point)
            let nextDistance = inside(next)
            if distance >= 0 {
                kept.append(point)
            }
            if (distance >= 0) != (nextDistance >= 0) {
                let fraction = distance / (distance - nextDistance)
                kept.append(Point(x: point.x + (next.x - point.x) * fraction, y: point.y + (next.y - point.y) * fraction))
            }
        }

        return kept
    }
}

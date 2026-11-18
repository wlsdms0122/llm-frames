//
//  ConvexPolygon.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// A convex polygon by its corners in order, either way round. An affine transform keeps it convex, and so does
// clipping it by another, so a rectangle carried through any transforms and cut by any masks stays one.
struct ConvexPolygon: Equatable, Sendable {
    // MARK: - Property
    // Below this a polygon is a line or a point and covers nothing.
    private static let minimumArea = 1e-9

    let corners: [Point]

    // Twice the signed area, positive when the corners turn clockwise with the y axis down.
    private var doubleArea: Double {
        corners.indices.reduce(0) { area, index in
            let corner = corners[index]
            let next = corners[(index + 1) % corners.count]

            return area + corner.x * next.y - next.x * corner.y
        }
    }

    // The axis-aligned box of its corners, nil when it covers nothing.
    var bounds: Rectangle? {
        guard !isEmpty else { return nil }

        let xs = corners.map(\.x)
        let ys = corners.map(\.y)
        // Not empty, so it has corners.
        let left = xs.min() ?? 0
        let top = ys.min() ?? 0

        return Rectangle(x: left, y: top, width: (xs.max() ?? 0) - left, height: (ys.max() ?? 0) - top)
    }

    var isEmpty: Bool {
        corners.count < 3 || abs(doubleArea) / 2 < Self.minimumArea
    }

    // MARK: - Initializer
    init(corners: [Point]) {
        self.corners = corners
    }

    // The rectangle's corners carried by the transform.
    init(
        rectangle: Rectangle,
        transform: AffineTransform = .identity
    ) {
        self.init(corners: transform.apply(toCornersOf: rectangle))
    }

    // The convex hull of the points by Andrew's monotone chain, which covers all a nonzero fill of them can.
    init(hullOf points: [Point]) {
        let sorted = points.sorted { ($0.x, $0.y) < ($1.x, $1.y) }
        let turnsClockwise = { (chain: [Point], point: Point) in
            Self.cross(from: chain[chain.count - 2], to: chain[chain.count - 1], point: point) > 0
        }
        let chain = { (points: [Point]) in
            points.reduce(into: [Point]()) { chain, point in
                while chain.count >= 2, !turnsClockwise(chain, point) {
                    chain.removeLast()
                }
                chain.append(point)
            }
        }
        let lower = chain(sorted)
        let upper = chain(sorted.reversed())

        self.init(corners: Array(lower.dropLast() + upper.dropLast()))
    }

    // MARK: - Public
    func applying(_ transform: AffineTransform) -> ConvexPolygon {
        ConvexPolygon(corners: corners.map(transform.apply(to:)))
    }

    // What lies inside both, by cutting this one along each edge of `other` in turn.
    func clipped(to other: ConvexPolygon) -> ConvexPolygon {
        guard !isEmpty, !other.isEmpty else { return ConvexPolygon(corners: []) }

        let turn = other.doubleArea > 0 ? 1.0 : -1.0
        let clipped = other.corners.indices.reduce(corners) { corners, index in
            let start = other.corners[index]
            let end = other.corners[(index + 1) % other.corners.count]
            let side = { (point: Point) in turn * Self.cross(from: start, to: end, point: point) }

            return corners.indices.flatMap { cornerIndex -> [Point] in
                let corner = corners[cornerIndex]
                let next = corners[(cornerIndex + 1) % corners.count]
                let cornerSide = side(corner)
                let nextSide = side(next)
                let kept = cornerSide >= 0 ? [corner] : []
                guard (cornerSide >= 0) != (nextSide >= 0) else { return kept }

                // The sides differ in sign, so they are not equal and the edge crosses the line between them.
                let progress = cornerSide / (cornerSide - nextSide)
                return kept + [Point.interpolate(from: corner, to: next, progress: progress)]
            }
        }

        return ConvexPolygon(corners: clipped)
    }

    // Whether the point lies inside or on its edge.
    func contains(_ point: Point) -> Bool {
        guard !isEmpty else { return false }

        let turn = doubleArea > 0 ? 1.0 : -1.0
        return corners.indices.allSatisfy { index in
            let next = corners[(index + 1) % corners.count]
            return turn * Self.cross(from: corners[index], to: next, point: point) >= 0
        }
    }

    // MARK: - Private
    // Positive when the point lies to the clockwise side of the line from `start` to `end`, with the y axis down.
    private static func cross(
        from start: Point,
        to end: Point,
        point: Point
    ) -> Double {
        (end.x - start.x) * (point.y - start.y) - (end.y - start.y) * (point.x - start.x)
    }
}

//
//  ItemCoverage+Path.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// What a `path` item covers in its own coordinates. A rect or an ellipse covers its rectangle grown by half its
// stroke, less the rectangle shrunk by half its stroke when it is not filled. A filled polyline covers the convex hull
// of its points, and its stroke as drawn after `trim` covers a band the stroke wide along each segment, its arrowheads
// added and the line stopping at their bases. Joins, caps, rounded corners, the curve of an ellipse and the trim of a
// rect or an ellipse are left out.
extension ItemCoverage {
    // MARK: - Property
    // MARK: - Initializer
    init(path: PathItem) {
        let stroke = path.drawnStroke?.isDrawn == true ? path.stroke : nil

        switch path.geometry {
        case let .rect(rectangle, _), let .ellipse(rectangle):
            let half = (stroke?.width ?? 0) / 2
            let outer = Self.inset(rectangle, by: -half)
            let inner = Self.inset(rectangle, by: half)
            let isHollow = path.fill == nil && inner.width > 0 && inner.height > 0
            self.init(
                pieces: path.fill == nil && stroke == nil ? [] : [ConvexPolygon(rectangle: outer)],
                holes: isHollow ? [ConvexPolygon(rectangle: inner)] : []
            )

        case let .polyline(points, isClosed):
            let fill = path.fill == nil ? [] : [ConvexPolygon(corners: Self.hull(of: points))]
            let line = Self.pieces(of: points, isClosed: isClosed, path: path)
            self.init(pieces: fill + line)
        }
    }

    // MARK: - Public
    // MARK: - Private
    private static func inset(
        _ rectangle: Rectangle,
        by distance: Double
    ) -> Rectangle {
        Rectangle(
            x: rectangle.x + distance,
            y: rectangle.y + distance,
            width: rectangle.width - 2 * distance,
            height: rectangle.height - 2 * distance
        )
    }

    // The stroke's segments between its arrowheads and the heads, as `DrawnStroke` lays them along the outline.
    private static func pieces(
        of points: [Point],
        isClosed: Bool,
        path: PathItem
    ) -> [ConvexPolygon] {
        let vertices = isClosed ? points + [points[0]] : points
        let segments = zip(vertices, vertices.dropFirst()).filter { distance(from: $0.0, to: $0.1) > 0 }
        let length = segments.map { distance(from: $0.0, to: $0.1) }.reduce(0, +)
        guard let stroke = path.stroke, let drawn = path.drawnStroke, drawn.isDrawn, length > 0 else { return [] }

        let lineStart = drawn.lineStart(along: length)
        let lineEnd = drawn.lineEnd(along: length)
        let headLength = drawn.headLength(along: length)
        let line = lineEnd > lineStart
            ? piece(of: segments, from: lineStart, to: lineEnd).map { start, end in
                band(from: start, to: end, width: stroke.width)
            }
            : []
        let startHead = drawn.hasStartHead
            ? head(at: drawn.start(along: length), of: segments, pointing: -1, length: headLength)
            : nil
        let endHead = drawn.hasEndHead
            ? head(at: drawn.end(along: length), of: segments, pointing: 1, length: headLength)
            : nil

        return line + [startHead, endHead].compactMap { $0 }
    }

    // The parts of the segments between two distances along them.
    private static func piece(
        of segments: [(Point, Point)],
        from start: Double,
        to end: Double
    ) -> [(Point, Point)] {
        var travelled = 0.0
        var parts: [(Point, Point)] = []
        for (from, to) in segments {
            let length = distance(from: from, to: to)
            defer { travelled += length }
            let lower = max(start - travelled, 0)
            let upper = min(end - travelled, length)
            guard upper > lower else { continue }

            parts.append((
                .interpolate(from: from, to: to, progress: lower / length),
                .interpolate(from: from, to: to, progress: upper / length)
            ))
        }

        return parts
    }

    // A head whose tip lies at `position` along the segments and whose axis points along them (`direction` 1) or back
    // (`direction` -1).
    private static func head(
        at position: Double,
        of segments: [(Point, Point)],
        pointing direction: Double,
        length: Double
    ) -> ConvexPolygon? {
        guard length > 0 else { return nil }

        let around = direction > 0
            ? piece(of: segments, from: 0, to: position).last
            : piece(of: segments, from: position, to: .infinity).first
        guard let around else { return nil }

        let (from, to) = around
        let size = distance(from: from, to: to)
        let axis = Point(x: (to.x - from.x) / size * direction, y: (to.y - from.y) / size * direction)
        let tip = direction > 0 ? to : from
        let base = Point(x: tip.x - axis.x * length, y: tip.y - axis.y * length)
        let across = Point(x: -axis.y * length / 2, y: axis.x * length / 2)

        return ConvexPolygon(corners: [
            Point(x: base.x + across.x, y: base.y + across.y),
            tip,
            Point(x: base.x - across.x, y: base.y - across.y)
        ])
    }

    private static func band(
        from start: Point,
        to end: Point,
        width: Double
    ) -> ConvexPolygon {
        let length = distance(from: start, to: end)
        let across = Point(x: -(end.y - start.y) / length * width / 2, y: (end.x - start.x) / length * width / 2)

        return ConvexPolygon(corners: [
            Point(x: start.x + across.x, y: start.y + across.y),
            Point(x: end.x + across.x, y: end.y + across.y),
            Point(x: end.x - across.x, y: end.y - across.y),
            Point(x: start.x - across.x, y: start.y - across.y)
        ])
    }

    // The convex hull by Andrew's monotone chain, which covers all a nonzero fill of the points can.
    private static func hull(of points: [Point]) -> [Point] {
        let sorted = points.sorted { ($0.x, $0.y) < ($1.x, $1.y) }
        let cross = { (origin: Point, first: Point, second: Point) in
            (first.x - origin.x) * (second.y - origin.y) - (first.y - origin.y) * (second.x - origin.x)
        }
        let chain = { (points: [Point]) in
            points.reduce(into: [Point]()) { chain, point in
                while chain.count >= 2, cross(chain[chain.count - 2], chain[chain.count - 1], point) <= 0 {
                    chain.removeLast()
                }
                chain.append(point)
            }
        }
        let lower = chain(sorted)
        let upper = chain(sorted.reversed())

        return Array(lower.dropLast() + upper.dropLast())
    }

    private static func distance(
        from start: Point,
        to end: Point
    ) -> Double {
        ((end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y)).squareRoot()
    }
}

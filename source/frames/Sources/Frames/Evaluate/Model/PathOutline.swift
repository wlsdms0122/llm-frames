//
//  PathOutline.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The outline of a path's geometry in y-down coordinates, clockwise as seen on the output from a fixed start, which
// trim fractions count from: a rect from the start of its top edge after the top left corner's arc, an ellipse from its
// top, a polyline from its first point along its points, the closing segment last. Segments of no length are left out,
// so every segment has a direction.
package struct PathOutline: Equatable, Sendable {
    // MARK: - Property
    package let isClosed: Bool
    package let length: Double
    package let start: Point
    package let segments: [OutlineSegment]

    // MARK: - Initializer
    package init(_ geometry: PathGeometry) {
        let segments: [OutlineSegment]
        switch geometry {
        case let .rect(rectangle, radius):
            let frame = Self.standardized(rectangle)
            let corner = max(0, min(radius, frame.width / 2, frame.height / 2))
            segments = Self.segments(of: frame, radius: corner)
            start = Point(x: frame.x + corner, y: frame.y)
            isClosed = true

        case let .ellipse(rectangle):
            let frame = Self.standardized(rectangle)
            let radii = Size(width: frame.width / 2, height: frame.height / 2)
            segments = [.arc(center: frame.center, radii: radii, start: -.pi / 2, sweep: 2 * .pi)]
            start = Point(x: frame.center.x, y: frame.y)
            isClosed = true

        case let .polyline(points, closed):
            let ends = closed ? points + points.prefix(1) : points
            segments = zip(ends, ends.dropFirst()).map { OutlineSegment.line(from: $0.0, to: $0.1) }
            start = points.first ?? Point(x: 0, y: 0)
            isClosed = closed
        }

        self.segments = segments.filter { $0.length > 0 }
        self.length = self.segments.map(\.length).reduce(0, +)
    }

    // MARK: - Public
    package func point(at distance: Double) -> Point {
        guard let found = segment(at: distance, leaving: true) else { return start }

        return found.segment.point(at: distance - found.offset)
    }

    // The unit direction of travel at a distance: of the segment leaving it, or with `leaving` false of the one
    // arriving at it, which differ at a corner.
    package func direction(
        at distance: Double,
        leaving: Bool
    ) -> Point {
        guard let found = segment(at: distance, leaving: leaving) else { return Point(x: 0, y: 0) }

        return found.segment.direction(at: distance - found.offset)
    }

    // The arrowheads of a stroke drawn along the outline, the start's first. The start's head points back along the
    // outline, the end's forward, each along the segment on the drawn side of its tip.
    package func arrowheads(of drawn: DrawnStroke) -> [Arrowhead] {
        guard length > 0 else { return [] }

        let size = drawn.headLength(along: length)
        guard size > 0 else { return [] }

        let start = drawn.hasStartHead ? head(at: drawn.start(along: length), isStart: true, length: size) : nil
        let end = drawn.hasEndHead ? head(at: drawn.end(along: length), isStart: false, length: size) : nil
        return [start, end].compactMap { $0 }
    }

    // The convex parts of what a stroke draws along the outline that lie past the outline grown by half the stroke's
    // width, each by its corners in order: its arrowheads, the points of its miter joins and the ends of its square
    // caps. A round or bevelled join and a round or butt cap lie within that grown outline.
    package func overhangs(
        of stroke: PathStroke,
        drawn: DrawnStroke
    ) -> [[Point]] {
        guard drawn.isDrawn, length > 0 else { return [] }

        let heads = arrowheads(of: drawn).map(\.corners)
        let lineStart = drawn.lineStart(along: length)
        let lineEnd = drawn.lineEnd(along: length)
        guard drawn.isWhole || lineEnd > lineStart else { return heads }

        let half = stroke.width / 2
        let joins = stroke.join == .miter
            ? corners(drawnBy: drawn).compactMap { corner in miter(at: corner, half: half) }
            : []
        let first = direction(at: lineStart, leaving: true)
        let caps = stroke.cap == .square && !drawn.isWhole
            ? [
                cap(at: lineStart, outward: Point(x: -first.x, y: -first.y), half: half),
                cap(at: lineEnd, outward: direction(at: lineEnd, leaving: false), half: half)
            ]
            : []

        return heads + joins + caps
    }

    // MARK: - Private
    // The rectangle with a size of no sign, covering the same points.
    private static func standardized(_ rectangle: Rectangle) -> Rectangle {
        Rectangle(
            x: min(rectangle.x, rectangle.x + rectangle.width),
            y: min(rectangle.y, rectangle.y + rectangle.height),
            width: abs(rectangle.width),
            height: abs(rectangle.height)
        )
    }

    // Top edge, top right corner, right edge and so on round to the top left corner.
    private static func segments(
        of frame: Rectangle,
        radius: Double
    ) -> [OutlineSegment] {
        let minX = frame.x
        let minY = frame.y
        let maxX = frame.maxX
        let maxY = frame.maxY
        let corner = { (x: Double, y: Double, start: Double) in
            OutlineSegment.arc(
                center: Point(x: x, y: y),
                radii: Size(width: radius, height: radius),
                start: start,
                sweep: .pi / 2
            )
        }

        return [
            .line(from: Point(x: minX + radius, y: minY), to: Point(x: maxX - radius, y: minY)),
            corner(maxX - radius, minY + radius, -.pi / 2),
            .line(from: Point(x: maxX, y: minY + radius), to: Point(x: maxX, y: maxY - radius)),
            corner(maxX - radius, maxY - radius, 0),
            .line(from: Point(x: maxX - radius, y: maxY), to: Point(x: minX + radius, y: maxY)),
            corner(minX + radius, maxY - radius, .pi / 2),
            .line(from: Point(x: minX, y: maxY - radius), to: Point(x: minX, y: minY + radius)),
            corner(minX + radius, minY + radius, .pi)
        ]
    }

    // The segment that holds a distance, with the distance at its start. At the joint of two segments `leaving` takes
    // the second and otherwise the first.
    private func segment(
        at distance: Double,
        leaving: Bool
    ) -> (segment: OutlineSegment, offset: Double)? {
        var offset = 0.0
        for segment in segments {
            let end = offset + segment.length
            if leaving ? distance < end : distance <= end { return (segment, offset) }
            offset = end
        }

        return segments.last.map { ($0, offset - $0.length) }
    }

    // The joints the drawn line turns at, each with the directions it arrives and leaves by: every joint of a whole
    // closed outline, the one at its start included, and of a drawn piece those strictly between its line's ends.
    private func corners(drawnBy drawn: DrawnStroke) -> [(point: Point, arriving: Point, leaving: Point)] {
        let lineStart = drawn.lineStart(along: length)
        let lineEnd = drawn.lineEnd(along: length)
        var offset = 0.0
        var joints: [(distance: Double, arriving: OutlineSegment, leaving: OutlineSegment)] = []
        for (arriving, leaving) in zip(segments, segments.dropFirst()) {
            offset += arriving.length
            joints.append((offset, arriving, leaving))
        }
        if isClosed, let last = segments.last, let first = segments.first {
            joints.append((length, last, first))
        }

        return joints
            .filter { joint in drawn.isWhole || (joint.distance > lineStart && joint.distance < lineEnd) }
            .map { joint in
                (
                    joint.leaving.point(at: 0),
                    joint.arriving.direction(at: joint.arriving.length),
                    joint.leaving.direction(at: 0)
                )
            }
    }

    // A miter join outside its corner, from the corner by the ends of both segments' stroke edges to the miter's point,
    // nil where the outline goes straight on or the miter passes the limit and is bevelled.
    private func miter(
        at corner: (point: Point, arriving: Point, leaving: Point),
        half: Double
    ) -> [Point]? {
        let (point, arriving, leaving) = corner
        let turn = arriving.x * leaving.x + arriving.y * leaving.y
        // The sine of half the angle between the two segments, whose inverse is the miter's length in stroke widths.
        let sine = ((1 + turn) / 2).squareRoot()
        let outside = Point(x: arriving.x - leaving.x, y: arriving.y - leaving.y)
        let size = (outside.x * outside.x + outside.y * outside.y).squareRoot()
        // A rounded corner's arc meets its edges in directions that differ only by rounding, and is not a corner.
        guard turn < 1 - 1e-9, sine * StrokeJoin.miterLimit >= 1, size > 0 else { return nil }

        let reach = half / sine
        let tip = Point(x: point.x + outside.x / size * reach, y: point.y + outside.y / size * reach)
        let edge = { (direction: Point) in
            let normal = Point(x: -direction.y, y: direction.x)
            let side = normal.x * outside.x + normal.y * outside.y > 0 ? half : -half
            return Point(x: point.x + normal.x * side, y: point.y + normal.y * side)
        }

        return [point, edge(arriving), tip, edge(leaving)]
    }

    // A square cap at a distance along the outline: the stroke's width across, half of it past the end along
    // `outward`, the unit direction away from the drawn line.
    private func cap(
        at distance: Double,
        outward: Point,
        half: Double
    ) -> [Point] {
        let end = point(at: distance)
        let along = Point(x: outward.x * half, y: outward.y * half)
        let across = Point(x: -along.y, y: along.x)

        return [
            Point(x: end.x + across.x, y: end.y + across.y),
            Point(x: end.x + across.x + along.x, y: end.y + across.y + along.y),
            Point(x: end.x - across.x + along.x, y: end.y - across.y + along.y),
            Point(x: end.x - across.x, y: end.y - across.y)
        ]
    }

    private func head(
        at distance: Double,
        isStart: Bool,
        length: Double
    ) -> Arrowhead {
        let direction = direction(at: distance, leaving: isStart)
        let sign = isStart ? -1.0 : 1.0
        return Arrowhead(
            tip: point(at: distance),
            axis: Point(x: direction.x * sign, y: direction.y * sign),
            length: length
        )
    }
}

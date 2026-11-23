//
//  PathOutline.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

import Foundation

// The outline of a path's geometry in y-down coordinates, clockwise in them from a fixed start, which trim fractions
// count from: a rect from the start of its top edge after the top left corner's arc, an ellipse from its
// top, a path from its first vertex along its vertices, the closing segment last. Segments of no length are left out,
// so every segment has a direction.
package struct PathOutline: Equatable, Sendable {
    // MARK: - Property
    package let isClosed: Bool
    package let length: Double
    package let start: Point
    package let segments: [OutlineSegment]
    // Each segment's length and the distance along the outline to its start, in the order of `segments`.
    package let lengths: [Double]
    package let offsets: [Double]

    // MARK: - Initializer
    package init(_ geometry: PathGeometry) {
        let segments: [OutlineSegment]
        let start: Point
        let isClosed: Bool
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

        case let .path(vertices, closed):
            let ends = closed ? vertices + vertices.prefix(1) : vertices
            segments = zip(ends, ends.dropFirst()).map { OutlineSegment.joining($0.0, $0.1) }
            start = vertices.first?.vertex ?? Point(x: 0, y: 0)
            isClosed = closed
        }

        let measured = segments.map { segment in (segment, segment.length) }.filter { _, length in length > 0 }
        self.init(isClosed: isClosed, start: start, segments: measured.map(\.0), lengths: measured.map(\.1))
    }

    private init(
        isClosed: Bool,
        start: Point,
        segments: [OutlineSegment],
        lengths: [Double]
    ) {
        var offsets: [Double] = []
        var length = 0.0
        for segmentLength in lengths {
            offsets.append(length)
            length += segmentLength
        }

        self.isClosed = isClosed
        self.start = start
        self.segments = segments
        self.lengths = lengths
        self.offsets = offsets
        self.length = length
    }

    // MARK: - Public
    // The outline carried by a map that does not flatten the plane, segment by segment, so its distances correspond
    // to this one's through `distance(_:onto:)`. A mirroring map turns its direction on the output.
    package func carried(by transform: AffineTransform) -> PathOutline {
        let carried = segments.map { $0.carried(by: transform) }
        return PathOutline(
            isClosed: isClosed,
            start: transform.apply(to: start),
            segments: carried,
            lengths: carried.map(\.length)
        )
    }

    // The distance along `other`, this outline carried or the one this was carried from, to the point this outline
    // reaches at `distance`.
    package func distance(
        _ distance: Double,
        onto other: PathOutline
    ) -> Double {
        guard distance < length else { return other.length }

        for index in segments.indices where index < other.segments.count {
            if distance < offsets[index] + lengths[index] {
                let along = other.segments[index].distance(distance - offsets[index], from: segments[index])
                return other.offsets[index] + along
            }
        }

        return other.length
    }

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

    // The arrowheads of a stroke drawn along the outline, the start's first (FRAMES-20 Arrowheads). Each has its tip at
    // its end of the stroke and the middle of its base on the stroke its length back along it, its axis the chord
    // between them, or where they are one point the direction at the tip, back along the outline for the start's.
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
        // A cusp turns back by half a circle, past the miter limit, so it is bevelled and adds nothing here.
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

    // The corners the drawn line turns at (FRAMES-20 Direction at a point), in order along it, each with the directions
    // it arrives and leaves by: the joints between segments whose directions there differ and the cusps inside
    // segments. A whole closed outline has every one, the joint at its start included, and a drawn piece those strictly
    // between its line's ends.
    package func corners(drawnBy drawn: DrawnStroke) -> [(point: Point, arriving: Point, leaving: Point)] {
        let lineStart = drawn.lineStart(along: length)
        let lineEnd = drawn.lineEnd(along: length)
        var corners: [(distance: Double, point: Point, arriving: Point, leaving: Point)] = []
        for (index, segment) in segments.enumerated() {
            for cusp in segment.cusps {
                let leaving = cusp.leaving
                let arriving = Point(x: -leaving.x, y: -leaving.y)
                corners.append((offsets[index] + cusp.distance, cusp.point, arriving, leaving))
            }
            let end = offsets[index] + lengths[index]

            let isLast = index == segments.count - 1
            guard !isLast || isClosed else { continue }

            let next = segments[isLast ? 0 : index + 1]
            let arriving = segment.direction(at: lengths[index])
            let leaving = next.direction(at: 0)
            // A rounded corner's arc meets its edges in directions that differ only by rounding, and is smooth.
            guard arriving.x * leaving.x + arriving.y * leaving.y < 1 - 1e-9 else { continue }

            corners.append((end, next.point(at: 0), arriving, leaving))
        }

        return corners
            .filter { corner in drawn.isWhole || (corner.distance > lineStart && corner.distance < lineEnd) }
            .map { corner in (corner.point, corner.arriving, corner.leaving) }
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
        for index in segments.indices {
            let end = offsets[index] + lengths[index]
            if leaving ? distance < end : distance <= end { return (segments[index], offsets[index]) }
        }

        return segments.indices.last.map { index in (segments[index], offsets[index]) }
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
        guard sine * StrokeJoin.miterLimit >= 1, size > 0 else { return nil }

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
        let tip = point(at: distance)
        let base = point(at: isStart ? distance + length : distance - length)
        let chord = Point(x: tip.x - base.x, y: tip.y - base.y)
        let size = hypot(chord.x, chord.y)
        guard size > 0 else {
            let direction = direction(at: distance, leaving: isStart)
            let sign = isStart ? -1.0 : 1.0
            return Arrowhead(tip: tip, axis: Point(x: direction.x * sign, y: direction.y * sign), length: 0, width: length)
        }

        return Arrowhead(tip: tip, axis: Point(x: chord.x / size, y: chord.y / size), length: size, width: length)
    }
}

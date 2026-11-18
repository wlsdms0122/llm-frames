//
//  PathOutline.swift
//  FramesQuartz
//
//  Created by JSilver on 11/18/26.
//

import CoreGraphics
import Foundation
import Frames

// The outline of a path's geometry in y-down coordinates, clockwise as seen on the output from a fixed start: a rect
// from the start of its top edge after the top left corner's arc, an ellipse from its top, a polyline from its first
// point along its points, the closing segment last. A rect's radius past half its shorter side is held at it.
// Segments of no length are left out, so every segment has a direction.
struct PathOutline {
    // MARK: - Property
    let isClosed: Bool
    let length: CGFloat

    private let start: CGPoint
    private let segments: [OutlineSegment]

    // The whole outline, closed when it is.
    var path: CGPath {
        piece(from: 0, to: length, closing: isClosed)
    }

    // The outline closed by a straight segment from its end to its start, for its fill.
    var fillPath: CGPath {
        piece(from: 0, to: length, closing: true)
    }

    // MARK: - Initializer
    init(_ geometry: PathGeometry) {
        let segments: [OutlineSegment]
        switch geometry {
        case let .rect(rectangle, radius):
            let frame = CGRect(rectangle).standardized
            let corner = max(0, min(radius, frame.width / 2, frame.height / 2))
            segments = Self.segments(of: frame, radius: corner)
            start = CGPoint(x: frame.minX + corner, y: frame.minY)
            isClosed = true

        case let .ellipse(rectangle):
            let frame = CGRect(rectangle).standardized
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let radii = CGSize(width: frame.width / 2, height: frame.height / 2)
            segments = [.arc(center: center, radii: radii, start: -.pi / 2, sweep: 2 * .pi)]
            start = CGPoint(x: frame.midX, y: frame.minY)
            isClosed = true

        case let .polyline(points, closed):
            let vertices = points.map { CGPoint(x: $0.x, y: $0.y) }
            let ends = closed ? vertices + vertices.prefix(1) : vertices
            segments = zip(ends, ends.dropFirst()).map { OutlineSegment.line(from: $0.0, to: $0.1) }
            start = vertices.first ?? .zero
            isClosed = closed
        }

        self.segments = segments.filter { $0.length > 0 }
        self.length = self.segments.map(\.length).reduce(0, +)
    }

    // MARK: - Public
    // The open piece between two distances along the outline.
    func piece(
        from start: CGFloat,
        to end: CGFloat
    ) -> CGPath {
        piece(from: start, to: end, closing: false)
    }

    func point(at distance: CGFloat) -> CGPoint {
        guard let found = segment(at: distance, leaving: true) else { return start }

        return found.segment.point(at: distance - found.offset)
    }

    // The unit direction of travel at a distance: of the segment leaving it, or with `leaving` false of the one
    // arriving at it, which differ at a corner.
    func direction(
        at distance: CGFloat,
        leaving: Bool
    ) -> CGPoint {
        guard let found = segment(at: distance, leaving: leaving) else { return .zero }

        return found.segment.direction(at: distance - found.offset)
    }

    // MARK: - Private
    // Top edge, top right corner, right edge and so on round to the top left corner.
    private static func segments(
        of frame: CGRect,
        radius: CGFloat
    ) -> [OutlineSegment] {
        let minX = frame.minX
        let minY = frame.minY
        let maxX = frame.maxX
        let maxY = frame.maxY
        let corner = { (x: CGFloat, y: CGFloat, start: CGFloat) in
            OutlineSegment.arc(
                center: CGPoint(x: x, y: y),
                radii: CGSize(width: radius, height: radius),
                start: start,
                sweep: .pi / 2
            )
        }

        return [
            .line(from: CGPoint(x: minX + radius, y: minY), to: CGPoint(x: maxX - radius, y: minY)),
            corner(maxX - radius, minY + radius, -.pi / 2),
            .line(from: CGPoint(x: maxX, y: minY + radius), to: CGPoint(x: maxX, y: maxY - radius)),
            corner(maxX - radius, maxY - radius, 0),
            .line(from: CGPoint(x: maxX - radius, y: maxY), to: CGPoint(x: minX + radius, y: maxY)),
            corner(minX + radius, maxY - radius, .pi / 2),
            .line(from: CGPoint(x: minX, y: maxY - radius), to: CGPoint(x: minX, y: minY + radius)),
            corner(minX + radius, minY + radius, .pi)
        ]
    }

    // The segment that holds a distance, with the distance at its start. At the joint of two segments `leaving` takes
    // the second and otherwise the first.
    private func segment(
        at distance: CGFloat,
        leaving: Bool
    ) -> (segment: OutlineSegment, offset: CGFloat)? {
        var offset: CGFloat = 0
        for segment in segments {
            let end = offset + segment.length
            if leaving ? distance < end : distance <= end { return (segment, offset) }
            offset = end
        }

        return segments.last.map { ($0, offset - $0.length) }
    }

    private func piece(
        from start: CGFloat,
        to end: CGFloat,
        closing: Bool
    ) -> CGPath {
        let path = CGMutablePath()
        path.move(to: point(at: start))

        // A whole closed outline leaves its last straight segment to the closing of the path, so its last corner and
        // the one at its start are joined as every other.
        let isWhole = closing && isClosed && start == 0 && end == length
        let drawn = isWhole && segments.last?.isLine == true ? segments.dropLast() : segments[...]
        var offset: CGFloat = 0
        for segment in drawn {
            let lower = max(start - offset, 0)
            let upper = min(end - offset, segment.length)
            if upper > lower { segment.append(from: lower, to: upper, to: path) }
            offset += segment.length
        }
        if closing { path.closeSubpath() }

        return path
    }
}

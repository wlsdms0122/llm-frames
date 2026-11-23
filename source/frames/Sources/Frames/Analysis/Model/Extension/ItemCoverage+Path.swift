//
//  ItemCoverage+Path.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// What a `path` item covers in its own coordinates. A rect or an ellipse covers its rectangle grown by half its stroke,
// less the rectangle shrunk by half its stroke when it is not filled. A filled path covers the convex hull of its
// vertices and their tangents' control points, which holds its curve. Its stroke as drawn after `trim` covers, the line
// stopping at its arrowheads' bases, a band the stroke wide along each straight segment, and along each curved one, cut
// into pieces of equal length, the hull of each piece's control points grown by half the stroke along both axes, which
// holds the stroke since a cubic lies in the hull of its control points. Each adds what its stroke draws past its
// outline grown by half its width (`PathItem.overhangs`): its arrowheads, miter joins and square caps. Bevels, round
// joins and caps, rounded corners, the curve of an ellipse and the trim of a rect or an ellipse are left out. The
// stroke is drawn in output pixels on the outline `transform` carries, so its band is taken at its width over the
// transform's length factor, exact where the transform scales both axes alike.
extension ItemCoverage {
    // MARK: - Property
    // The pieces a curved segment is cut into, whose control points lie closer to the curve the more there are.
    private static let curvePieces = 16

    // MARK: - Initializer
    init(
        path: PathItem,
        carriedBy transform: AffineTransform
    ) {
        let stroke = path.drawnStroke?.isDrawn == true ? path.stroke : nil
        let overhangs = path.overhangs(carriedBy: transform).map(ConvexPolygon.init(corners:))
        let factor = transform.lengthFactor
        let width = factor > 0 ? (stroke?.width ?? 0) / factor : 0

        switch path.geometry {
        case let .rect(rectangle, _), let .ellipse(rectangle):
            let half = width / 2
            let outer = Self.inset(rectangle, by: -half)
            let inner = Self.inset(rectangle, by: half)
            let isHollow = path.fill == nil && inner.width > 0 && inner.height > 0
            self.init(
                pieces: (path.fill == nil && stroke == nil ? [] : [ConvexPolygon(rectangle: outer)]) + overhangs,
                holes: isHollow ? [ConvexPolygon(rectangle: inner)] : []
            )

        case let .path(vertices, _):
            let controls = vertices.flatMap { vertex in
                [vertex.inTangent, Point(x: 0, y: 0), vertex.outTangent].map { tangent in
                    Point(x: vertex.vertex.x + tangent.x, y: vertex.vertex.y + tangent.y)
                }
            }
            let fill = path.fill == nil ? [] : [ConvexPolygon(hullOf: controls)]
            let line = Self.pieces(of: PathOutline(path.geometry), path: path, width: width)
            self.init(pieces: fill + line + overhangs)
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

    // The stroke's segments between its arrowheads, as `DrawnStroke` lays them along the outline.
    private static func pieces(
        of outline: PathOutline,
        path: PathItem,
        width: Double
    ) -> [ConvexPolygon] {
        guard let drawn = path.drawnStroke, drawn.isDrawn, outline.length > 0 else { return [] }

        let lineStart = drawn.lineStart(along: outline.length)
        let lineEnd = drawn.lineEnd(along: outline.length)
        guard lineEnd > lineStart else { return [] }

        var travelled = 0.0
        var parts: [ConvexPolygon] = []
        for segment in outline.segments {
            defer { travelled += segment.length }
            let lower = max(lineStart - travelled, 0)
            let upper = min(lineEnd - travelled, segment.length)
            guard upper > lower else { continue }

            parts += bands(along: segment.piece(from: lower, to: upper), width: width)
        }

        return parts
    }

    private static func bands(
        along segment: OutlineSegment,
        width: Double
    ) -> [ConvexPolygon] {
        let half = width / 2
        let corners = [(-half, -half), (half, -half), (half, half), (-half, half)]
        let grown = { (points: [Point]) in
            ConvexPolygon(hullOf: points.flatMap { point in
                corners.map { Point(x: point.x + $0, y: point.y + $1) }
            })
        }

        switch segment {
        case let .line(start, end):
            let length = ((end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y)).squareRoot()
            let across = Point(x: -(end.y - start.y) / length * half, y: (end.x - start.x) / length * half)

            return [ConvexPolygon(corners: [
                Point(x: start.x + across.x, y: start.y + across.y),
                Point(x: end.x + across.x, y: end.y + across.y),
                Point(x: end.x - across.x, y: end.y - across.y),
                Point(x: start.x - across.x, y: start.y - across.y)
            ])]

        case .cubic:
            let step = segment.length / Double(curvePieces)
            return (0..<curvePieces).compactMap { index in
                guard
                    case let .cubic(from, first, second, to) = segment.piece(
                        from: Double(index) * step,
                        to: Double(index + 1) * step
                    )
                else { return nil }

                return grown([from, first, second, to])
            }

        // A path's outline has no arc. The whole ellipse's box holds any part of it.
        case let .arc(center, xAxis, yAxis, _, _):
            let reach = Point(x: abs(xAxis.x) + abs(yAxis.x), y: abs(xAxis.y) + abs(yAxis.y))
            return [grown([(-1.0, -1.0), (1, -1), (1, 1), (-1, 1)].map { x, y in
                Point(x: center.x + x * reach.x, y: center.y + y * reach.y)
            })]
        }
    }
}

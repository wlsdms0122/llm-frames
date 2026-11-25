//
//  ItemCoverage+Path.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// What a `path` item covers in its own coordinates. A rect or an ellipse covers its rectangle grown by as far as its
// stroke reaches past it, less the rectangle shrunk by as far as the stroke lies inside it when it is not filled. A
// filled path covers the convex hull of the control points of its outline's segments, which holds its curve and the
// straight segment its fill closes an open path with, and leaves out the tangents of an open path's ends, which shape
// nothing it draws. A coverage is a union of convex pieces, so a concave fill covers its hull. Its stroke as drawn
// after `trim` covers, the line stopping where its arrowheads stop it, a band the centred stroke it is cut from wide
// along each straight segment, and along each curved one, cut into pieces of equal length, the hull of each piece's
// control points grown by half that stroke along both axes, which holds the stroke since a cubic lies in the hull of
// its control points. Each arrowhead is a filled closed path and covers what a filled path's outline covers. Each adds
// what its stroke's line draws past its outline grown by its reach (`PathItem.overhangs`): its miter joins and square
// caps. The half of the band an inside or outside stroke is cut from, the side it does not lie on, is left in. Bevels,
// round joins and caps, rounded corners, the curve of an ellipse and the trim of a rect or an ellipse are left out.
// The stroke is drawn in output pixels on the outline `transform` carries, and its line's ends and heads are laid
// there, so its band is taken at its width over the transform's length factor, exact where the transform scales both
// axes alike.
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
            + path.heads(carriedBy: transform).map(Self.filled)
        let factor = transform.lengthFactor
        let width = factor > 0 ? (stroke?.width ?? 0) / factor : 0
        let reach = stroke?.align.reach ?? 0

        switch path.geometry {
        case let .rect(rectangle, _), let .ellipse(rectangle):
            let outer = Self.inset(rectangle, by: -width * reach)
            let inner = Self.inset(rectangle, by: width * (1 - reach))
            let isHollow = path.fill == nil && inner.width > 0 && inner.height > 0
            self.init(
                pieces: (path.fill == nil && stroke == nil ? [] : [ConvexPolygon(rectangle: outer)]) + overhangs,
                holes: isHollow ? [ConvexPolygon(rectangle: inner)] : []
            )

        case .path:
            let outline = PathOutline(path.geometry)
            let fill = path.fill == nil ? [] : [Self.filled(path.geometry)]
            let line = Self.pieces(
                of: outline,
                path: path,
                carriedBy: transform,
                width: stroke.map { $0.align.tracedWidth(of: width) } ?? 0
            )
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

    // What a path's fill covers: the convex hull of the control points of its outline's segments.
    private static func filled(_ geometry: PathGeometry) -> ConvexPolygon {
        ConvexPolygon(hullOf: PathOutline(geometry).segments.flatMap(\.hullPoints))
    }

    // The stroke's segments between its arrowheads along `outline`, the item's own, its line's ends laid on the
    // outline `transform` carries and brought back.
    private static func pieces(
        of outline: PathOutline,
        path: PathItem,
        carriedBy transform: AffineTransform,
        width: Double
    ) -> [ConvexPolygon] {
        guard case let (carried, drawn)? = path.carriedStroke(by: transform), drawn.isDrawn else { return [] }

        let lineStart = carried.distance(carried.lineStart(of: drawn), onto: outline)
        let lineEnd = carried.distance(carried.lineEnd(of: drawn), onto: outline)
        guard lineEnd > lineStart else { return [] }

        var parts: [ConvexPolygon] = []
        for (index, segment) in outline.segments.enumerated() {
            let lower = max(lineStart - outline.offsets[index], 0)
            let upper = min(lineEnd - outline.offsets[index], outline.lengths[index])
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
            return (0..<curvePieces).map { index in
                grown(segment.piece(from: Double(index) * step, to: Double(index + 1) * step).hullPoints)
            }

        case .arc:
            return [grown(segment.hullPoints)]
        }
    }
}

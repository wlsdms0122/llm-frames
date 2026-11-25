//
//  PathDrawer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/18/26.
//

import CoreGraphics
import Foundation
import Frames

// Draws a path item in its own coordinates: its fill, then its stroke over it. The stroke runs along its outline
// between the smaller and the larger trim, centred, and stops where each of its arrowheads stops it. An inside or an
// outside stroke is that centred stroke twice its width, its joins, caps and dashes included, cut to the inside of the
// outline, the region its fill covers by the nonzero rule, or to the outside of it. It is laid in output pixels on the
// outline `transform` carries (`PathItem.carriedStroke(by:)`), so a transform that scales its axes apart does not
// stretch it, and drawn back in the item's coordinates.
// The stroked line and its heads are united into one shape filled once, so a translucent colour is not drawn twice
// where they overlap. Dashes are laid in the item's own distances along the outline, from the start of the stroke as
// drawn, so they stretch with it, and cut where the heads stop the line; the heads are drawn whole. A dash with no
// length above 0 draws the stroke whole. A gradient paints the fill or the stroke's shape through it as a clip, laid in
// the item's own coordinates.
struct PathDrawer {
    // MARK: - Property
    private let gradients = GradientDrawer()

    // MARK: - Initializer
    // MARK: - Public
    func draw(
        _ item: PathItem,
        carriedBy transform: Frames.AffineTransform,
        in context: CGContext
    ) {
        let outline = PathOutline(item.geometry)

        if let fill = item.fill {
            paint(outline.fillPath, with: fill, in: context)
        }

        guard
            let stroke = item.stroke,
            let back = transform.inverse,
            case let (carried, drawn)? = item.carriedStroke(by: transform),
            drawn.isDrawn,
            let traced = shape(of: stroke.traced, drawn: drawn, along: carried, own: outline),
            let shape = traced.cut(to: stroke.align, of: carried)
        else { return }

        var matrix = CGAffineTransform(back)
        guard let placed = shape.copy(using: &matrix) else { return }

        paint(placed, with: stroke.paint, in: context)
    }

    // MARK: - Private
    // The stroke's dash lengths, nil for a whole stroke.
    private func pattern(of stroke: PathStroke) -> [Double]? {
        stroke.dash.flatMap { dash in dash.contains { $0 > 0 } ? dash : nil }
    }

    // The inside of `path` by the nonzero rule.
    private func paint(
        _ path: CGPath,
        with paint: Paint,
        in context: CGContext
    ) {
        context.addPath(path)
        switch paint {
        case let .color(color):
            context.setFillColor(color.cgColor)
            context.fillPath(using: .winding)

        case let .gradient(gradient):
            context.saveGState()
            context.clip(using: .winding)
            gradients.draw(gradient, in: context)
            context.restoreGState()
        }
    }

    // The stroke and its arrowheads as one shape, nil where it draws nothing.
    private func shape(
        of stroke: PathStroke,
        drawn: DrawnStroke,
        along outline: PathOutline,
        own: PathOutline
    ) -> CGPath? {
        guard !drawn.isWhole || pattern(of: stroke) != nil else { return stroked(outline.path, by: stroke) }

        let line = line(
            of: stroke,
            from: drawn.start(along: outline.length),
            between: outline.lineStart(of: drawn),
            and: outline.lineEnd(of: drawn),
            along: outline,
            own: own
        )
        let parts = [line].compactMap { $0 } + outline.arrowheads(of: drawn).map(path(of:))
        guard let first = parts.first else { return nil }

        return parts.dropFirst().reduce(first) { shape, part in shape.union(part, using: .winding) }
    }

    // The stroked line from `lower` to `upper` along the carried outline, nil where it is empty. A dash pattern starts
    // `dashOffset` before `start`, where the stroke as drawn starts, and each dash is taken in the item's own distances
    // and carried onto the outline.
    private func line(
        of stroke: PathStroke,
        from start: Double,
        between lower: Double,
        and upper: Double,
        along outline: PathOutline,
        own: PathOutline
    ) -> CGPath? {
        guard upper > lower else { return nil }
        guard let dash = pattern(of: stroke) else { return stroked(outline.piece(from: lower, to: upper), by: stroke) }

        let first = outline.distance(lower, onto: own)
        let last = outline.distance(upper, onto: own)
        let period = dash.reduce(0, +)
        // A whole period keeps the pattern where it is, so it is begun the part of a period it has run before `first`.
        let behind = (first - outline.distance(start, onto: own) + stroke.dashOffset)
            .truncatingRemainder(dividingBy: period)
        var position = first - (behind < 0 ? behind + period : behind)
        let dashes = CGMutablePath()
        var dots = [CGPath]()
        for index in 0... {
            guard position < last else { break }

            let next = position + dash[index % dash.count]
            let from = max(position, first)
            let to = min(next, last)
            if index.isMultiple(of: 2), to > from {
                dashes.addPath(outline.piece(from: own.distance(from, onto: outline), to: own.distance(to, onto: outline)))
            } else if index.isMultiple(of: 2), next == position, position >= first,
                let dot = dot(of: stroke, at: own.distance(position, onto: outline), along: outline) {
                dots.append(dot)
            }
            position = next
        }
        let parts = (dashes.isEmpty ? [] : [stroked(dashes, by: stroke)]) + dots
        guard let base = parts.first else { return nil }

        return parts.dropFirst().reduce(base) { shape, dot in shape.union(dot, using: .winding) }
    }

    // A dash of no length: its caps alone, a circle for `round` and a square along the outline's
    // direction for `square`, and nothing for `butt`.
    private func dot(
        of stroke: PathStroke,
        at distance: Double,
        along outline: PathOutline
    ) -> CGPath? {
        let center = outline.point(at: distance)
        let half = stroke.width / 2
        switch stroke.cap {
        case .butt:
            return nil

        case .round:
            return CGPath(ellipseIn: CGRect(x: center.x - half, y: center.y - half, width: 2 * half, height: 2 * half), transform: nil)

        case .square:
            let along = outline.direction(at: distance, leaving: true)
            let across = Point(x: -along.y, y: along.x)
            let corners = [(1.0, 1.0), (1.0, -1.0), (-1.0, -1.0), (-1.0, 1.0)].map { forward, side in
                CGPoint(
                    x: center.x + (forward * along.x + side * across.x) * half,
                    y: center.y + (forward * along.y + side * across.y) * half
                )
            }
            let path = CGMutablePath()
            path.addLines(between: corners)
            path.closeSubpath()

            return path
        }
    }

    private func stroked(
        _ path: CGPath,
        by stroke: PathStroke
    ) -> CGPath {
        path.copy(
            strokingWithWidth: CGFloat(stroke.width),
            lineCap: lineCap(of: stroke.cap),
            lineJoin: lineJoin(of: stroke.join),
            miterLimit: CGFloat(StrokeJoin.miterLimit)
        )
    }

    // A head as one shape, the fill of its outline.
    private func path(of head: Arrowhead) -> CGPath {
        PathOutline(head.geometry()).fillPath
    }

    private func lineCap(of cap: StrokeCap) -> CGLineCap {
        switch cap {
        case .butt:
            .butt

        case .round:
            .round

        case .square:
            .square
        }
    }

    private func lineJoin(of join: StrokeJoin) -> CGLineJoin {
        switch join {
        case .miter:
            .miter

        case .round:
            .round

        case .bevel:
            .bevel
        }
    }
}

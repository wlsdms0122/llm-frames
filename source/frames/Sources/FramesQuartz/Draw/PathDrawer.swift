//
//  PathDrawer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/18/26.
//

import CoreGraphics
import Foundation
import Frames

// Draws a path item in its own coordinates: its fill first, by the nonzero rule with an open polyline closed, then its
// stroke over it. The stroke is drawn along its outline between the smaller and the larger trim, centred, with its
// join under a miter limit of 4 and its cap on the ends of an open piece. An arrowhead is a triangle `4 × width` long
// and wide with its tip at its end of the drawn stroke and its axis along the outline there, the line stopping at the
// middle of its base; heads longer together than the drawn stroke shrink about their tips to share its length. The
// stroked line and its heads are united into one shape filled once, so a translucent colour is not drawn twice where
// they overlap.
struct PathDrawer {
    // MARK: - Property
    // SVG's default `stroke-miterlimit`.
    private static let miterLimit: CGFloat = 4

    // MARK: - Initializer
    // MARK: - Public
    func draw(
        _ item: PathItem,
        in context: CGContext
    ) {
        let outline = PathOutline(item.geometry)

        if let fill = item.fill {
            context.addPath(outline.fillPath)
            context.setFillColor(fill.cgColor)
            context.fillPath(using: .winding)
        }

        guard
            let stroke = item.stroke,
            let drawn = item.drawnStroke(length: Double(outline.length)),
            let shape = shape(of: stroke, drawn: drawn, along: outline)
        else { return }

        context.addPath(shape)
        context.setFillColor(stroke.color.cgColor)
        context.fillPath(using: .winding)
    }

    // MARK: - Private
    // The stroke and its arrowheads as one shape, nil where it draws nothing.
    private func shape(
        of stroke: PathStroke,
        drawn: DrawnStroke,
        along outline: PathOutline
    ) -> CGPath? {
        guard !drawn.isWhole else { return stroked(outline.path, by: stroke) }

        let lineStart = CGFloat(drawn.lineStart)
        let lineEnd = CGFloat(drawn.lineEnd)
        let headLength = CGFloat(drawn.headLength)
        let line = lineEnd > lineStart ? stroked(outline.piece(from: lineStart, to: lineEnd), by: stroke) : nil
        let start = drawn.hasStartHead
            ? head(at: CGFloat(drawn.start), along: outline, isStart: true, length: headLength)
            : nil
        let end = drawn.hasEndHead
            ? head(at: CGFloat(drawn.end), along: outline, isStart: false, length: headLength)
            : nil
        let parts = [line, start, end].compactMap { $0 }
        guard let first = parts.first else { return nil }

        return parts.dropFirst().reduce(first) { shape, part in shape.union(part, using: .winding) }
    }

    private func stroked(
        _ path: CGPath,
        by stroke: PathStroke
    ) -> CGPath {
        path.copy(
            strokingWithWidth: CGFloat(stroke.width),
            lineCap: lineCap(of: stroke.cap),
            lineJoin: lineJoin(of: stroke.join),
            miterLimit: Self.miterLimit
        )
    }

    // A head with its tip at a distance along the outline, pointing along the outline's direction there, or against it
    // at the start of the stroke.
    private func head(
        at distance: CGFloat,
        along outline: PathOutline,
        isStart: Bool,
        length: CGFloat
    ) -> CGPath? {
        guard length > 0 else { return nil }

        let tip = outline.point(at: distance)
        let direction = outline.direction(at: distance, leaving: isStart)
        let sign: CGFloat = isStart ? -1 : 1
        let axis = CGPoint(x: direction.x * sign, y: direction.y * sign)
        let base = CGPoint(x: tip.x - axis.x * length, y: tip.y - axis.y * length)
        let across = CGPoint(x: -axis.y * length / 2, y: axis.x * length / 2)
        let path = CGMutablePath()
        path.addLines(between: [
            CGPoint(x: base.x + across.x, y: base.y + across.y),
            tip,
            CGPoint(x: base.x - across.x, y: base.y - across.y)
        ])
        path.closeSubpath()

        return path
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

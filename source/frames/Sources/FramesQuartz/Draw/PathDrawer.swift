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
// join under a miter limit of 4 and its cap on the ends of an open piece. Its arrowheads lie where the outline lays
// them (`PathOutline.arrowheads(of:)`), the line stopping at the middle of their bases. The stroked line and its heads
// are united into one shape filled once, so a translucent colour is not drawn twice where they overlap.
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
            let drawn = item.drawnStroke,
            drawn.isDrawn,
            outline.length > 0,
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

        let lineStart = drawn.lineStart(along: outline.length)
        let lineEnd = drawn.lineEnd(along: outline.length)
        let line = lineEnd > lineStart ? stroked(outline.piece(from: lineStart, to: lineEnd), by: stroke) : nil
        let parts = [line].compactMap { $0 } + outline.arrowheads(of: drawn).map(path(of:))
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

    private func path(of head: Arrowhead) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: head.corners.map { CGPoint(x: $0.x, y: $0.y) })
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

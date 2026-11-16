//
//  ShapeDrawer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Foundation
import Frames

// Draws fills, strokes and arrows in their item's own coordinates.
struct ShapeDrawer {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The hole is cut by the even-odd rule.
    func draw(
        _ fill: FillItem,
        in context: CGContext
    ) {
        context.addPath(RoundedOutline(rectangle: fill.rectangle, radius: fill.radius).path)
        if let hole = fill.hole { context.addPath(RoundedOutline(hole).path) }
        context.setFillColor(fill.color.cgColor)
        context.fillPath(using: .evenOdd)
    }

    // A trimmed outline ends square at both ends.
    func draw(
        _ stroke: StrokeItem,
        in context: CGContext
    ) {
        guard stroke.width > 0, stroke.trim > 0 else { return }

        context.addPath(RoundedOutline(rectangle: stroke.rectangle, radius: stroke.radius).path(trim: stroke.trim))
        context.setLineWidth(stroke.width)
        context.setLineCap(.butt)
        context.setLineJoin(.miter)
        context.setStrokeColor(stroke.color.cgColor)
        context.strokePath()
    }

    // A shaft `width` wide from the tail, square at its end, to the base of a triangular head whose length and base
    // are both `headSize`, its tip at `head`. On an arrow shorter than its head the head shrinks to the arrow's length.
    func draw(
        _ arrow: ArrowItem,
        in context: CGContext
    ) {
        let dx = arrow.head.x - arrow.tail.x
        let dy = arrow.head.y - arrow.tail.y
        let length = hypot(dx, dy)
        guard length > 0 else { return }

        let along = CGPoint(x: dx / length, y: dy / length)
        let across = CGPoint(x: -along.y, y: along.x)
        let headLength = min(arrow.headSize, length)
        let tip = CGPoint(x: arrow.head.x, y: arrow.head.y)
        let base = CGPoint(x: tip.x - along.x * headLength, y: tip.y - along.y * headLength)
        let tail = CGPoint(x: arrow.tail.x, y: arrow.tail.y)
        let shaft = arrow.width / 2
        let head = headLength / 2
        let points = [
            offset(tail, by: across, distance: shaft),
            offset(base, by: across, distance: shaft),
            offset(base, by: across, distance: head),
            tip,
            offset(base, by: across, distance: -head),
            offset(base, by: across, distance: -shaft),
            offset(tail, by: across, distance: -shaft)
        ]

        context.addLines(between: points)
        context.closePath()
        context.setFillColor(arrow.color.cgColor)
        context.fillPath(using: .winding)
    }

    // MARK: - Private
    private func offset(
        _ point: CGPoint,
        by direction: CGPoint,
        distance: CGFloat
    ) -> CGPoint {
        CGPoint(x: point.x + direction.x * distance, y: point.y + direction.y * distance)
    }
}

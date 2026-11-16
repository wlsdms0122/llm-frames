//
//  ShapeDrawer.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Decides how a shape is drawn from the theme, for an image operation and a sequence clip alike, and lays a drawing on
// an area.
struct ShapeDrawer: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    init() { }

    // MARK: - Public
    // `scale` is the length scale theme lengths are multiplied by.
    func drawing(
        of shape: ShapeForm,
        color: Color,
        scale: Double,
        theme: MergedTheme
    ) -> ShapeDrawing {
        switch shape {
        case .box:
            .box(width: theme.boxWidth * scale, radius: theme.boxRadius * scale, color: color)

        case .fill:
            .fill(color: color)

        case .dim:
            .dim(color: color)

        case let .arrow(side):
            .arrow(
                side: side,
                length: theme.arrowLength * scale,
                width: theme.arrowWidth * scale,
                head: theme.arrowHead * scale,
                color: color
            )
        }
    }

    // The step a drawing makes on an area, and the box its label is measured beside: the area, or the arrow's.
    func content(
        of drawing: ShapeDrawing,
        on area: Rectangle
    ) -> (content: DrawingContent, box: Rectangle) {
        switch drawing {
        case let .box(width, radius, color):
            return (.box(area, width: width, radius: radius, color: color), area)

        case let .fill(color):
            return (.fill(area, color: color), area)

        case let .dim(color):
            return (.dim(area, color: color), area)

        case let .arrow(side, length, width, head, color):
            let arrow = Arrow(pointingAt: area, from: side, length: length, breadth: max(head, width))
            return (.arrow(tail: arrow.tail, tip: arrow.tip, width: width, head: head, color: color), arrow.box)
        }
    }

    // MARK: - Private
}

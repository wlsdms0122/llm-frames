//
//  ShapeDrawer.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Decides how a shape clip is drawn from the theme, and lays a drawing on an area.
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

    // What a drawing draws on an area, and the box its animation acts about: the area, or the arrow's. Its lengths are
    // divided by `scale`, the scale above 0 its area's space is drawn at, so they stay the same in output pixels.
    func content(
        of drawing: ShapeDrawing,
        on area: Rectangle,
        scale: Double
    ) -> (content: ShapeContent, box: Rectangle) {
        switch drawing {
        case let .box(width, radius, color):
            return (.box(area, width: width / scale, radius: radius / scale, color: color), area)

        case let .fill(color):
            return (.fill(area, color: color), area)

        case let .dim(color):
            return (.dim(area, color: color), area)

        case let .arrow(side, length, width, head, color):
            let arrow = Arrow(pointingAt: area, from: side, length: length / scale, breadth: max(head, width) / scale)
            return (
                .arrow(tail: arrow.tail, tip: arrow.tip, width: width / scale, head: head / scale, color: color),
                arrow.box
            )
        }
    }

    // MARK: - Private
}

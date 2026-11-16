//
//  DrawingStep+Transform.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// Carries a drawing step with its canvas when a later canvas operation scales or moves that canvas, its lengths
// included.
extension DrawingStep {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func transformed(by transform: CanvasTransform) -> DrawingStep {
        DrawingStep(content: content(transformedBy: transform), clip: transform.rectangle(clip))
    }

    // MARK: - Private
    private func content(transformedBy transform: CanvasTransform) -> DrawingContent {
        switch content {
        case let .picture(picture, crop, frame):
            .picture(picture, crop: crop, frame: transform.rectangle(frame))

        case let .fill(rectangle, color):
            .fill(transform.rectangle(rectangle), color: color)

        case let .box(rectangle, width, radius, color):
            .box(
                transform.rectangle(rectangle),
                width: transform.length(width),
                radius: transform.length(radius),
                color: color
            )

        case let .dim(rectangle, color):
            .dim(transform.rectangle(rectangle), color: color)

        case let .arrow(tail, tip, width, head, color):
            .arrow(
                tail: transform.point(tail),
                tip: transform.point(tip),
                width: transform.length(width),
                head: transform.length(head),
                color: color
            )

        case let .adjustment(operations, area):
            .adjustment(operations.map { $0.scaled(by: transform.horizontalScale) }, area: transform.rectangle(area))

        case let .text(layout, frame):
            .text(layout, frame: transform.rectangle(frame))

        case let .border(rectangle, width, color):
            .border(transform.rectangle(rectangle), width: transform.length(width), color: color)
        }
    }
}

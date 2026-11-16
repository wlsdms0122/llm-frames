//
//  ImageCanvas.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The canvas of an image document as its operations run: its size, how the media pixels of its source land on it, and
// what is drawn so far, each step clipped to the canvas it was drawn on. A later crop clips what is drawn and cuts the
// source picture's crop with it, and later room around the canvas never reveals what was clipped.
struct ImageCanvas: Equatable, Sendable {
    // MARK: - Property
    private(set) var size: Size
    private(set) var transform: CanvasTransform
    private(set) var steps: [DrawingStep]

    var bounds: Rectangle {
        Rectangle(x: 0, y: 0, width: size.width, height: size.height)
    }

    // MARK: - Initializer
    // The canvas starts as the source picture, which fills it.
    init(
        picture: DrawnPicture,
        size: Size
    ) {
        let bounds = Rectangle(x: 0, y: 0, width: size.width, height: size.height)
        self.size = size
        self.transform = .identity
        self.steps = [DrawingStep(content: .picture(picture, crop: bounds, frame: bounds), clip: bounds)]
    }

    // MARK: - Public
    mutating func draw(_ content: DrawingContent) {
        steps.append(DrawingStep(content: content, clip: bounds))
    }

    // `rectangle` lies inside the canvas, and becomes it.
    mutating func crop(to rectangle: Rectangle) {
        let move = CanvasTransform(
            horizontalScale: 1,
            verticalScale: 1,
            offset: Point(x: -rectangle.x, y: -rectangle.y)
        )
        steps = steps.compactMap { step in
            guard let clip = step.clip.intersection(rectangle) else { return nil }

            return DrawingStep(content: cropped(step.content, to: clip), clip: clip).transformed(by: move)
        }
        size = Size(width: rectangle.width, height: rectangle.height)
        transform = transform.followed(by: move)
    }

    // The canvas becomes `size`, and everything on it maps onto it from the old canvas, one factor per axis.
    mutating func resize(to size: Size) {
        let resize = CanvasTransform(
            horizontalScale: size.width / self.size.width,
            verticalScale: size.height / self.size.height,
            offset: Point(x: 0, y: 0)
        )
        steps = steps.map { $0.transformed(by: resize) }
        self.size = size
        transform = transform.followed(by: resize)
    }

    // Adds room around the canvas, filled with `color`.
    mutating func extend(
        by inset: Inset,
        color: Color
    ) {
        let move = CanvasTransform(
            horizontalScale: 1,
            verticalScale: 1,
            offset: Point(x: inset.left, y: inset.top)
        )
        let old = move.rectangle(bounds)
        steps = steps.map { $0.transformed(by: move) }
        size = Size(width: size.width + inset.left + inset.right, height: size.height + inset.top + inset.bottom)
        transform = transform.followed(by: move)
        for rectangle in room(around: old) {
            draw(.fill(rectangle, color: color))
        }
    }

    // MARK: - Private
    // A picture keeps only what the clip leaves of it, so its crop is cut in its own pixels.
    private func cropped(
        _ content: DrawingContent,
        to clip: Rectangle
    ) -> DrawingContent {
        guard case let .picture(picture, crop, frame) = content, let visible = frame.intersection(clip) else {
            return content
        }

        let horizontalScale = crop.width / frame.width
        let verticalScale = crop.height / frame.height

        return .picture(
            picture,
            crop: Rectangle(
                x: crop.x + (visible.x - frame.x) * horizontalScale,
                y: crop.y + (visible.y - frame.y) * verticalScale,
                width: visible.width * horizontalScale,
                height: visible.height * verticalScale
            ),
            frame: visible
        )
    }

    // The bands of the canvas outside `inner`: above and below it across the width, and beside it.
    private func room(around inner: Rectangle) -> [Rectangle] {
        [
            Rectangle(x: 0, y: 0, width: size.width, height: inner.y),
            Rectangle(x: 0, y: inner.maxY, width: size.width, height: size.height - inner.maxY),
            Rectangle(x: 0, y: inner.y, width: inner.x, height: inner.height),
            Rectangle(x: inner.maxX, y: inner.y, width: size.width - inner.maxX, height: inner.height)
        ].filter { $0.width > 0 && $0.height > 0 }
    }
}

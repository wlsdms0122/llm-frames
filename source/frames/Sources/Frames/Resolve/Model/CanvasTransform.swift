//
//  CanvasTransform.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How the canvas operations so far move a place: scaled by `scale` about the origin, then moved by `offset`.
struct CanvasTransform: Equatable, Sendable {
    // MARK: - Property
    static let identity = CanvasTransform(scale: 1, offset: Point(x: 0, y: 0))

    let scale: Double
    let offset: Point

    // MARK: - Initializer
    init(
        scale: Double,
        offset: Point
    ) {
        self.scale = scale
        self.offset = offset
    }

    // MARK: - Public
    func point(_ point: Point) -> Point {
        Point(x: point.x * scale + offset.x, y: point.y * scale + offset.y)
    }

    func rectangle(_ rectangle: Rectangle) -> Rectangle {
        Rectangle(
            x: rectangle.x * scale + offset.x,
            y: rectangle.y * scale + offset.y,
            width: rectangle.width * scale,
            height: rectangle.height * scale
        )
    }

    func length(_ length: Double) -> Double {
        length * scale
    }

    // This transform, then `next`.
    func followed(by next: CanvasTransform) -> CanvasTransform {
        CanvasTransform(scale: scale * next.scale, offset: next.point(offset))
    }

    func inverted() -> CanvasTransform {
        CanvasTransform(scale: 1 / scale, offset: Point(x: -offset.x / scale, y: -offset.y / scale))
    }

    // MARK: - Private
}

//
//  CanvasTransform.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How the canvas operations so far move a place: scaled about the origin by `horizontalScale` and `verticalScale`, then
// moved by `offset`. A length is scaled horizontally, as theme lengths are scaled by the canvas width.
struct CanvasTransform: Equatable, Sendable {
    // MARK: - Property
    static let identity = CanvasTransform(horizontalScale: 1, verticalScale: 1, offset: Point(x: 0, y: 0))

    let horizontalScale: Double
    let verticalScale: Double
    let offset: Point

    // MARK: - Initializer
    init(
        horizontalScale: Double,
        verticalScale: Double,
        offset: Point
    ) {
        self.horizontalScale = horizontalScale
        self.verticalScale = verticalScale
        self.offset = offset
    }

    // MARK: - Public
    func point(_ point: Point) -> Point {
        Point(x: point.x * horizontalScale + offset.x, y: point.y * verticalScale + offset.y)
    }

    func rectangle(_ rectangle: Rectangle) -> Rectangle {
        Rectangle(
            x: rectangle.x * horizontalScale + offset.x,
            y: rectangle.y * verticalScale + offset.y,
            width: rectangle.width * horizontalScale,
            height: rectangle.height * verticalScale
        )
    }

    func length(_ length: Double) -> Double {
        length * horizontalScale
    }

    // This transform, then `next`.
    func followed(by next: CanvasTransform) -> CanvasTransform {
        CanvasTransform(
            horizontalScale: horizontalScale * next.horizontalScale,
            verticalScale: verticalScale * next.verticalScale,
            offset: next.point(offset)
        )
    }

    func inverted() -> CanvasTransform {
        CanvasTransform(
            horizontalScale: 1 / horizontalScale,
            verticalScale: 1 / verticalScale,
            offset: Point(x: -offset.x / horizontalScale, y: -offset.y / verticalScale)
        )
    }

    // MARK: - Private
}

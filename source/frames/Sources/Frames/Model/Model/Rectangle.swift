//
//  Rectangle.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct Rectangle: Interpolable {
    // MARK: - Property
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var center: Point {
        Point(x: x + width / 2, y: y + height / 2)
    }

    // MARK: - Initializer
    init(
        x: Double,
        y: Double,
        width: Double,
        height: Double
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    init(
        center: Point,
        width: Double,
        height: Double
    ) {
        self.init(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }

    // MARK: - Public
    static func interpolate(
        from start: Rectangle,
        to end: Rectangle,
        progress: Double
    ) -> Rectangle {
        Rectangle(
            x: .interpolate(from: start.x, to: end.x, progress: progress),
            y: .interpolate(from: start.y, to: end.y, progress: progress),
            width: .interpolate(from: start.width, to: end.width, progress: progress),
            height: .interpolate(from: start.height, to: end.height, progress: progress)
        )
    }

    // MARK: - Private
}

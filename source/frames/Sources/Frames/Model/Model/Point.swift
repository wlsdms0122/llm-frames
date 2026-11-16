//
//  Point.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

struct Point: Interpolable {
    // MARK: - Property
    let x: Double
    let y: Double

    // MARK: - Initializer
    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    // MARK: - Public
    static func interpolate(
        from start: Point,
        to end: Point,
        progress: Double
    ) -> Point {
        Point(
            x: .interpolate(from: start.x, to: end.x, progress: progress),
            y: .interpolate(from: start.y, to: end.y, progress: progress)
        )
    }

    // MARK: - Private
}

//
//  Crop.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

import Foundation

// A conformed crop. Its centre moves in a straight line and its size changes geometrically, so a zoom keeps one speed.
struct Crop: Interpolable {
    // MARK: - Property
    let rectangle: Rectangle

    // MARK: - Initializer
    init(_ rectangle: Rectangle) {
        self.rectangle = rectangle
    }

    // MARK: - Public
    static func interpolate(
        from start: Crop,
        to end: Crop,
        progress: Double
    ) -> Crop {
        let center = Point.interpolate(from: start.rectangle.center, to: end.rectangle.center, progress: progress)
        return Crop(Rectangle(
            center: center,
            width: geometric(from: start.rectangle.width, to: end.rectangle.width, progress: progress),
            height: geometric(from: start.rectangle.height, to: end.rectangle.height, progress: progress)
        ))
    }

    // MARK: - Private
    private static func geometric(
        from start: Double,
        to end: Double,
        progress: Double
    ) -> Double {
        exp(.interpolate(from: log(start), to: log(end), progress: progress))
    }
}

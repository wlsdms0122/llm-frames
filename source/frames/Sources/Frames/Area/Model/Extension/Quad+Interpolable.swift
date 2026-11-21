//
//  Quad+Interpolable.swift
//  Frames
//
//  Created by JSilver on 11/22/26.
//

// A quad interpolates corner by corner, as a corner pin's points do (FRAMES-27 The key).
extension Quad: Interpolable {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    static func interpolate(
        from start: Quad,
        to end: Quad,
        progress: Double
    ) -> Quad {
        Quad(
            topLeft: .interpolate(from: start.topLeft, to: end.topLeft, progress: progress),
            topRight: .interpolate(from: start.topRight, to: end.topRight, progress: progress),
            bottomRight: .interpolate(from: start.bottomRight, to: end.bottomRight, progress: progress),
            bottomLeft: .interpolate(from: start.bottomLeft, to: end.bottomLeft, progress: progress)
        )
    }

    // MARK: - Private
}

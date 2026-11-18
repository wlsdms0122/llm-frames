//
//  Trim.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The part of an outline a stroke draws, `[start, end]` as fractions of its length.
// Either may be the larger.
package struct Trim: Interpolable {
    // MARK: - Property
    package static let whole = Trim(start: 0, end: 1)

    package let start: Double
    package let end: Double

    // MARK: - Initializer
    package init(
        start: Double,
        end: Double
    ) {
        self.start = start
        self.end = end
    }

    // MARK: - Public
    static func interpolate(
        from start: Trim,
        to end: Trim,
        progress: Double
    ) -> Trim {
        Trim(
            start: .interpolate(from: start.start, to: end.start, progress: progress),
            end: .interpolate(from: start.end, to: end.end, progress: progress)
        )
    }

    // MARK: - Private
}

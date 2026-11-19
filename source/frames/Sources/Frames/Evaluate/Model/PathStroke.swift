//
//  PathStroke.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A stroke centred on an outline.
package struct PathStroke: Equatable, Sendable {
    // MARK: - Property
    package let width: Double
    package let color: Color
    package let join: StrokeJoin
    package let cap: StrokeCap
    package let start: StrokeEnd
    package let end: StrokeEnd

    // MARK: - Initializer
    package init(
        width: Double,
        color: Color,
        join: StrokeJoin,
        cap: StrokeCap,
        start: StrokeEnd,
        end: StrokeEnd
    ) {
        self.width = width
        self.color = color
        self.join = join
        self.cap = cap
        self.start = start
        self.end = end
    }

    // MARK: - Public
    // MARK: - Private
}

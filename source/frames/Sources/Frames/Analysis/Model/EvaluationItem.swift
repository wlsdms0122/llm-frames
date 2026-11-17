//
//  EvaluationItem.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// One item `evaluate` reports: the clip that drew it, nil for the background, a transition cover and the background
// outside the content rect, the axis-aligned box of what it covers of the output, nil when it covers nothing, and its
// opacity times that of every picture holding it.
package struct EvaluationItem: Equatable, Sendable {
    // MARK: - Property
    package let origin: ItemOrigin?
    package let bounds: Rectangle?
    package let opacity: Double

    // MARK: - Initializer
    init(
        origin: ItemOrigin?,
        bounds: Rectangle?,
        opacity: Double
    ) {
        self.origin = origin
        self.bounds = bounds
        self.opacity = opacity
    }

    init(_ item: FlattenedItem) {
        self.init(origin: item.origin, bounds: item.coverage.bounds, opacity: item.opacity)
    }

    // MARK: - Public
    // MARK: - Private
}

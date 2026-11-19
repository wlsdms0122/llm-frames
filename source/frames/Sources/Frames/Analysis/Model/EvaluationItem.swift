//
//  EvaluationItem.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// One item `evaluate` reports: the clip that drew it, nil for the background and a transition cover, what it draws,
// the axis-aligned box of what it covers of the output, nil when it covers nothing, and its opacity times that of
// every picture holding it.
package struct EvaluationItem: Equatable, Sendable {
    // MARK: - Property
    package let origin: ItemOrigin?
    package let item: ItemKind
    package let bounds: Rectangle?
    package let opacity: Double

    // MARK: - Initializer
    init(
        origin: ItemOrigin?,
        item: ItemKind,
        bounds: Rectangle?,
        opacity: Double
    ) {
        self.origin = origin
        self.item = item
        self.bounds = bounds
        self.opacity = opacity
    }

    init(_ item: FlattenedItem) {
        self.init(origin: item.origin, item: item.item, bounds: item.coverage.bounds, opacity: item.opacity)
    }

    // MARK: - Public
    // MARK: - Private
}

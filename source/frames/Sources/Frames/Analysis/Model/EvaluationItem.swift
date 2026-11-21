//
//  EvaluationItem.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// One item `evaluate` reports: the clip that drew it, nil for the background and a transition cover, what it draws,
// the axis-aligned box of what it covers of the output, nil when it covers nothing, its opacity times that of every
// picture holding it, the map from its own coordinates to output pixels, and its extent in its own coordinates before
// its reveal, its masks and the pictures holding it cut it.
package struct EvaluationItem: Equatable, Sendable {
    // MARK: - Property
    package let origin: ItemOrigin?
    package let item: ItemKind
    package let bounds: Rectangle?
    package let opacity: Double
    package let transform: AffineTransform
    package let rect: Rectangle

    // MARK: - Initializer
    init(
        origin: ItemOrigin?,
        item: ItemKind,
        bounds: Rectangle?,
        opacity: Double,
        transform: AffineTransform,
        rect: Rectangle
    ) {
        self.origin = origin
        self.item = item
        self.bounds = bounds
        self.opacity = opacity
        self.transform = transform
        self.rect = rect
    }

    init(_ item: FlattenedItem) {
        self.init(
            origin: item.origin,
            item: item.item,
            bounds: item.coverage.bounds,
            opacity: item.opacity,
            transform: item.transform,
            rect: item.rect
        )
    }

    // MARK: - Public
    // MARK: - Private
}

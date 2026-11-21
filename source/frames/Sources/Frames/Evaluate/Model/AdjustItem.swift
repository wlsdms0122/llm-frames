//
//  AdjustItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A filter applied to everything drawn below it, over the whole frame of its list, cut only by its item's mask, reveal
// and opacity.
package struct AdjustItem: Equatable, Sendable {
    // MARK: - Property
    package let filter: [FilterEntry]

    // MARK: - Initializer
    package init(filter: [FilterEntry]) {
        self.filter = filter
    }

    // MARK: - Public
    // What the item draws in its own coordinates, which its reveal wipes across: the frame of its list carried back by
    // the inverse of `transform`, since the item covers that frame wherever its transform carries its reveal. Nil where
    // the transform flattens the plane, which leaves nothing drawn.
    package func drawnBounds(
        carriedBy transform: AffineTransform,
        over frame: Rectangle
    ) -> Rectangle? {
        guard let inverse = transform.inverse else { return nil }

        return Rectangle(bounding: inverse.apply(toCornersOf: frame))
    }

    // MARK: - Private
}

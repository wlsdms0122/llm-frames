//
//  PageRegion.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

import Foundation

// A region of a page's pixel grid at a scale s (FRAMES-21 Rules): `width` by `height` grid pixels from pixel (`x`, `y`).
// Grid pixel (i, j) covers the page's media pixels (i / s, j / s) to ((i + 1) / s, (j + 1) / s), anchored at media pixel
// (0, 0), the top left of the page as it is displayed.
package struct PageRegion: Equatable, Hashable, Sendable {
    // MARK: - Property
    package let x: Int
    package let y: Int
    package let width: Int
    package let height: Int

    // MARK: - Initializer
    package init(
        x: Int,
        y: Int,
        width: Int,
        height: Int
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    // The whole page of `size` media pixels at `scale`: [0, 0, max(1, round(w × s)), max(1, round(h × s))].
    package init(
        wholePageOf size: Size,
        scale: Double
    ) {
        self.init(
            x: 0,
            y: 0,
            width: max(1, Int((size.width * scale).rounded())),
            height: max(1, Int((size.height * scale).rounded()))
        )
    }

    // MARK: - Public
    // MARK: - Private
}

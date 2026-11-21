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

    // The whole page of `size` media pixels at `scale`: [0, 0, max(1, round(w × s)), max(1, round(h × s))]. Nil where
    // a side is over `largest`, the most pixels on a side the decoder holds, judged before a side is a whole number.
    package init?(
        wholePageOf size: Size,
        scale: Double,
        largest: Int
    ) {
        let side = Self.wholePageSide(of: size, scale: scale)
        guard max(side.width, side.height) <= Double(largest) else { return nil }

        self.init(x: 0, y: 0, width: Int(side.width), height: Int(side.height))
    }

    // The whole page of `size` media pixels at `scale`, or where the decoder does not hold it at `scale`, at the
    // largest scale at which it holds the whole page, its longer side `largest` (FRAMES-21 Rules), with that scale.
    package static func wholePage(
        of size: Size,
        atMost scale: Double,
        largest: Int
    ) -> (region: PageRegion, scale: Double) {
        let held = heldScale(of: size, atMost: scale, largest: largest)
        let side = wholePageSide(of: size, scale: held)
        let region = PageRegion(
            x: 0,
            y: 0,
            width: Int(min(side.width, Double(largest))),
            height: Int(min(side.height, Double(largest)))
        )

        return (region, held)
    }

    // MARK: - Public
    // `scale`, or where the decoder does not hold a picture of `size` media pixels at `scale`, the largest scale at
    // which it does, its longer side `largest` (FRAMES-21 Rules).
    package static func heldScale(
        of size: Size,
        atMost scale: Double,
        largest: Int
    ) -> Double {
        min(scale, Double(largest) / max(size.width, size.height))
    }

    // The sides of the whole page of `size` media pixels at `scale` in grid pixels, max(1, round(w × s)) by
    // max(1, round(h × s)), which may be past every whole number.
    package static func wholePageSide(
        of size: Size,
        scale: Double
    ) -> Size {
        Size(width: max(1, (size.width * scale).rounded()), height: max(1, (size.height * scale).rounded()))
    }

    // MARK: - Private
}

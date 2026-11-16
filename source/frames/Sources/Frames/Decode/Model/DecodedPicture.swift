//
//  DecodedPicture.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// A picture in the working space, as the media is displayed: `width` by `height` pixels of RGBA with premultiplied
// alpha, sRGB encoded, rows top first and `bytesPerRow` apart in `pixels`. Each component has `depth`'s bits, at the
// media's bit depth or more, and sixteen bit ones are in the machine's byte order.
package struct DecodedPicture: Equatable, Sendable {
    // MARK: - Property
    package let width: Int
    package let height: Int
    package let depth: BitDepth
    package let bytesPerRow: Int
    package let pixels: Data

    // MARK: - Initializer
    package init(
        width: Int,
        height: Int,
        depth: BitDepth,
        bytesPerRow: Int,
        pixels: Data
    ) {
        self.width = width
        self.height = height
        self.depth = depth
        self.bytesPerRow = bytesPerRow
        self.pixels = pixels
    }

    // MARK: - Public
    // MARK: - Private
}

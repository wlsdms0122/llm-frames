//
//  Bitmap.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// A picture of working values, as a decoder reads it, a renderer draws it and an encoder writes it: `width` by
// `height` pixels of RGBA with premultiplied alpha, extended-range sRGB encoded, rows top first and `bytesPerRow` apart
// in `pixels`. Each component is in `depth`'s form, at the media's bit depth or more: an unsigned integer holds 0 to 1,
// and a half float holds values below 0 and above 1 too. Sixteen bit integers and half floats are in the machine's byte
// order.
package struct Bitmap: Equatable, Sendable {
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

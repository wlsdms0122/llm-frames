//
//  Bitmap+Pixel.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames

extension Bitmap {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Premultiplied red, green, blue and alpha of the pixel at column `x` and row `y` from the top, from 0 to 1 at
    // every depth, and as stored in half floats.
    func pixel(
        x: Int,
        y: Int
    ) -> [Double] {
        pixels.withUnsafeBytes { buffer in
            let row = buffer.baseAddress!.advanced(by: y * bytesPerRow)
            switch depth {
            case .eight:
                let components = row.assumingMemoryBound(to: UInt8.self)

                return (0..<4).map { component in Double(components[x * 4 + component]) / 255 }

            case .sixteen:
                let components = row.assumingMemoryBound(to: UInt16.self)

                return (0..<4).map { component in Double(UInt16(littleEndian: components[x * 4 + component])) / 65535 }

            case .halfFloat:
                let components = row.assumingMemoryBound(to: Float16.self)

                return (0..<4).map { component in Double(components[x * 4 + component]) }
            }
        }
    }

    // Whether the pixel is `color`, unpremultiplied red, green and blue from 0 to 255 over full alpha, to within
    // `tolerance` of the 0 to 1 range in every component.
    func isPixel(
        x: Int,
        y: Int,
        _ color: [Double],
        tolerance: Double
    ) -> Bool {
        let pixel = pixel(x: x, y: y)
        let expected = color.map { $0 / 255 } + [1]

        return zip(pixel, expected).allSatisfy { abs($0 - $1) <= tolerance }
    }

    // MARK: - Private
}

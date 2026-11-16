//
//  Bitmap+Pixel.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames

// Reading a rendered sixteen bit bitmap back as premultiplied components from 0 to 1.
extension Bitmap {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Red, green, blue and alpha of the pixel at column `x` and row `y` from the top.
    func pixel(
        x: Int,
        y: Int
    ) -> [Double] {
        pixels.withUnsafeBytes { buffer in
            let row = buffer.baseAddress!.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt16.self)

            return (0..<4).map { component in Double(UInt16(littleEndian: row[x * 4 + component])) / 65535 }
        }
    }

    // The raw sixteen bit components of the pixel, for comparing pixels exactly.
    func components(
        x: Int,
        y: Int
    ) -> [UInt16] {
        pixels.withUnsafeBytes { buffer in
            let row = buffer.baseAddress!.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt16.self)

            return (0..<4).map { component in UInt16(littleEndian: row[x * 4 + component]) }
        }
    }

    // MARK: - Private
}

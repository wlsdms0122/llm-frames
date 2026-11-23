//
//  DisplacementMapWriter.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/23/26.
//

import CoreGraphics
import Foundation
import Frames
import ImageIO
import UniformTypeIdentifiers

// Writes an opaque sRGB PNG of `size` whose red and green samples are the code values a test gives for each pixel, as
// they are, at 8 or 16 bits per component, and whose blue samples are 0.
package struct DisplacementMapWriter {
    // MARK: - Property
    private let size: Size
    private let bitsPerComponent: Int

    // MARK: - Initializer
    package init(
        size: Size,
        bitsPerComponent: Int = 16
    ) {
        self.size = size
        self.bitsPerComponent = bitsPerComponent
    }

    // MARK: - Public
    // `codeValues` gives the red and green code values of the pixel at a column and row from the top left.
    package func write(
        to path: String,
        codeValues: (_ column: Int, _ row: Int) -> (red: Int, green: Int)
    ) throws {
        let width = Int(size.width)
        let height = Int(size.height)
        let samples = (0..<height).flatMap { row in
            (0..<width).flatMap { column in
                let value = codeValues(column, row)

                return [value.red, value.green, 0]
            }
        }
        let isSixteen = bitsPerComponent == 16
        let pixels = isSixteen
            ? samples.map { UInt16($0).littleEndian }.withUnsafeBufferPointer { Data(buffer: $0) }
            : Data(samples.map { UInt8($0) })
        let bitmapInfo = isSixteen
            ? CGImageAlphaInfo.none.rawValue | CGBitmapInfo.byteOrder16Little.rawValue
            : CGImageAlphaInfo.none.rawValue
        guard
            let provider = CGDataProvider(data: pixels as CFData),
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bitsPerPixel: bitsPerComponent * 3,
                bytesPerRow: width * bitsPerComponent / 8 * 3,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            ),
            let destination = CGImageDestinationCreateWithURL(
                URL(fileURLWithPath: path) as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else {
            throw TestMediaError.unwritable(path)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw TestMediaError.unwritable(path) }
    }

    // MARK: - Private
}

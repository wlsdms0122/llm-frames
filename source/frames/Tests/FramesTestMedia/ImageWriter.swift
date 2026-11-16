//
//  ImageWriter.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/16/26.
//

import CoreGraphics
import Foundation
import Frames
import ImageIO
import UniformTypeIdentifiers

// Writes an sRGB PNG of `size` drawn by a test, with 8 or 16 bits per component.
package struct ImageWriter {
    // MARK: - Property
    private let size: Size
    private let bitsPerComponent: Int

    // MARK: - Initializer
    package init(
        size: Size,
        bitsPerComponent: Int = 8
    ) {
        self.size = size
        self.bitsPerComponent = bitsPerComponent
    }

    // MARK: - Public
    package func write(
        to path: String,
        drawing: (Canvas) -> Void
    ) throws {
        let bitmapInfo = bitsPerComponent == 16
            ? CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder16Little.rawValue
            : CGImageAlphaInfo.premultipliedLast.rawValue
        guard
            let context = CGContext(
                data: nil,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: bitmapInfo
            )
        else {
            throw TestMediaError.unwritable(path)
        }
        drawing(Canvas(context: context, size: size))

        guard
            let image = context.makeImage(),
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

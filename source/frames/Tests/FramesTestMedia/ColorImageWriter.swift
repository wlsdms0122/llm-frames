//
//  ColorImageWriter.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/20/26.
//

import CoreGraphics
import Foundation
import Frames
import ImageIO
import UniformTypeIdentifiers

// Writes an opaque 8-bit image of one colour whose samples are the code values given, as they are, with the ICC profile
// of `colorSpace` embedded: a PNG for an RGB space, a JPEG for a CMYK one, one code value for each of its components.
package struct ColorImageWriter {
    // MARK: - Property
    private let size: Size
    private let colorSpace: CGColorSpace

    // MARK: - Initializer
    package init(
        size: Size,
        colorSpace: CGColorSpace
    ) {
        self.size = size
        self.colorSpace = colorSpace
    }

    // MARK: - Public
    package func write(
        to path: String,
        codeValues: [UInt8]
    ) throws {
        let width = Int(size.width)
        let height = Int(size.height)
        let components = colorSpace.numberOfComponents
        guard codeValues.count == components else { throw TestMediaError.unwritable(path) }

        let pixels = Data((0..<(width * height)).flatMap { _ in codeValues })
        let isCMYK = colorSpace.model == .cmyk
        guard
            let provider = CGDataProvider(data: pixels as CFData),
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 8 * components,
                bytesPerRow: width * components,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            ),
            let destination = CGImageDestinationCreateWithURL(
                URL(fileURLWithPath: path) as CFURL,
                (isCMYK ? UTType.jpeg : UTType.png).identifier as CFString,
                1,
                nil
            )
        else {
            throw TestMediaError.unwritable(path)
        }
        let options = isCMYK ? [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary : nil
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { throw TestMediaError.unwritable(path) }
    }

    // MARK: - Private
}

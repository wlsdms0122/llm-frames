//
//  PictureConverter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import CoreImage
import Foundation
import Frames

// Renders a decoded image into the working space: sRGB encoded RGBA with premultiplied alpha, rows top first. Core
// Image converts from the colour space the image is tagged with.
struct PictureConverter: Sendable {
    // MARK: - Property
    private static let workingSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    private let context: CIContext

    // MARK: - Initializer
    init() {
        context = CIContext(options: [.cacheIntermediates: false])
    }

    // MARK: - Public
    func picture(
        from image: CIImage,
        bitsPerComponent: Int
    ) -> DecodedPicture {
        let placed = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        let width = Int(placed.extent.width.rounded())
        let height = Int(placed.extent.height.rounded())
        let isDeep = bitsPerComponent > 8
        let bytesPerRow = width * (isDeep ? 8 : 4)
        var pixels = Data(count: bytesPerRow * height)
        pixels.withUnsafeMutableBytes { buffer in
            context.render(
                placed,
                toBitmap: buffer.baseAddress!,
                rowBytes: bytesPerRow,
                bounds: CGRect(x: 0, y: 0, width: width, height: height),
                format: isDeep ? .RGBA16 : .RGBA8,
                colorSpace: Self.workingSpace
            )
        }

        return DecodedPicture(
            width: width,
            height: height,
            bitsPerComponent: isDeep ? 16 : 8,
            bytesPerRow: bytesPerRow,
            pixels: pixels
        )
    }

    // MARK: - Private
}

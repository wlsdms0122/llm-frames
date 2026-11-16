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
        depth: BitDepth
    ) -> Bitmap {
        let placed = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        let width = Int(placed.extent.width.rounded())
        let height = Int(placed.extent.height.rounded())
        let bytesPerRow = width * 4 * depth.bitsPerComponent / 8
        var pixels = Data(count: bytesPerRow * height)
        pixels.withUnsafeMutableBytes { buffer in
            context.render(
                placed,
                toBitmap: buffer.baseAddress!,
                rowBytes: bytesPerRow,
                bounds: CGRect(x: 0, y: 0, width: width, height: height),
                format: depth == .sixteen ? .RGBA16 : .RGBA8,
                colorSpace: Self.workingSpace
            )
        }

        return Bitmap(
            width: width,
            height: height,
            depth: depth,
            bytesPerRow: bytesPerRow,
            pixels: pixels
        )
    }

    // MARK: - Private
}

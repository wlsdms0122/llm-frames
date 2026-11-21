//
//  PageRasterizer.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Foundation

// Draws a page of a PDF with Core Graphics into a bitmap of 32-bit floats, RGBA with premultiplied alpha, rows top
// first, where nothing is painted transparent, or over opaque white where `isOverWhite` is set. Core Graphics draws no
// annotations, and does not clip to the crop box, so `clip` is the part of user space drawn. A bitmap Core Graphics
// cannot make stops.
struct PageRasterizer {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    static func pixels(
        of page: CGPDFPage,
        width: Int,
        height: Int,
        transform: CGAffineTransform,
        clip: CGRect?,
        space: CGColorSpace,
        intent: CGColorRenderingIntent = .defaultIntent,
        isOverWhite: Bool = false
    ) throws -> [Float] {
        var pixels = [Float](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            guard
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 32,
                    bytesPerRow: width * 16,
                    space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.floatComponents.rawValue
                        | CGBitmapInfo.byteOrder32Little.rawValue
                )
            else {
                throw DecoderError.pageBitmap(width: width, height: height)
            }

            context.setRenderingIntent(intent)
            if isOverWhite, let white = CGColor(colorSpace: space, components: [1, 1, 1, 1]) {
                context.setFillColor(white)
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
            context.concatenate(transform)
            if let clip { context.clip(to: clip) }
            context.drawPDFPage(page)
        }

        return pixels
    }

    // MARK: - Private
}

//
//  PageRasterizer.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Foundation

// Draws a page of a PDF with Core Graphics into a bitmap of 32-bit floats, RGBA with premultiplied alpha, rows top
// first, where nothing is painted transparent. Core Graphics draws no annotations, and does not clip to the crop box, so
// `clip` is the part of user space drawn.
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
        intent: CGColorRenderingIntent = .defaultIntent
    ) -> [Float] {
        var pixels = [Float](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
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
                return
            }

            context.setRenderingIntent(intent)
            context.concatenate(transform)
            if let clip { context.clip(to: clip) }
            context.drawPDFPage(page)
        }

        return pixels
    }

    // MARK: - Private
}

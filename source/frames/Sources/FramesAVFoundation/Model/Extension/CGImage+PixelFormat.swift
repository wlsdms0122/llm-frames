//
//  CGImage+PixelFormat.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/25/26.
//

import CoreGraphics

extension CGImage {
    // MARK: - Property
    // How the image holds its samples, `<bits>-bit <integer | float> <channels>` (FRAMES-23 Runs).
    var pixelFormat: String {
        let hasAlpha = ![.none, .noneSkipFirst, .noneSkipLast].contains(alphaInfo)
        let isGray = colorSpace?.model == .monochrome
        let channels = switch (isGray, hasAlpha) {
        case (true, false):
            "gray"

        case (true, true):
            "gray alpha"

        case (false, false):
            "RGB"

        case (false, true):
            "RGBA"
        }
        let kind = bitmapInfo.contains(.floatComponents) ? "float" : "integer"

        return "\(bitsPerComponent)-bit \(kind) \(channels)"
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

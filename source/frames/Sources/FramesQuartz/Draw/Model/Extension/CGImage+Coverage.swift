//
//  CGImage+Coverage.swift
//  FramesQuartz
//
//  Created by JSilver on 11/18/26.
//

import CoreGraphics
import Foundation

// The grey image an item's alpha is multiplied by, made from its masks' and track matte's values.
extension CGImage {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // An eight bit grey image of the values, rows from the top, each held to [0, 1]. A clip takes its mask from an
    // eight bit grey image only, and leaves a sixteen bit one unapplied.
    static func coverage(
        of values: [Double],
        width: Int,
        height: Int
    ) throws -> CGImage {
        let samples = values.map { UInt8((min(max($0, 0), 1) * Double(UInt8.max)).rounded()) }
        guard
            let provider = CGDataProvider(data: Data(samples) as CFData),
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            throw QuartzError.unmadeBitmap(width: width, height: height)
        }

        return image
    }

    // MARK: - Private
}

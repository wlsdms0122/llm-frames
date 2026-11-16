//
//  Bitmap+CoreGraphics.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Foundation
import Frames

extension Bitmap {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The bitmap's pixels as a Core Graphics image in the working space, without copying them.
    func cgImage() throws -> CGImage {
        let bitsPerComponent = depth.bitsPerComponent
        let bitmapInfo = depth == .sixteen ? WorkingSpace.bitmapInfo : CGImageAlphaInfo.premultipliedLast.rawValue
        guard
            let provider = CGDataProvider(data: pixels as CFData),
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bitsPerPixel: bitsPerComponent * 4,
                bytesPerRow: bytesPerRow,
                space: WorkingSpace.colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
        else {
            throw QuartzError.unmadeBitmap(width: width, height: height)
        }

        return image
    }

    // MARK: - Private
}

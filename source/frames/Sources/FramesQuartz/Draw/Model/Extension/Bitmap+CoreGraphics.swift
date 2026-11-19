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
    // The bitmap's pixels as a Core Graphics image of encoded working values, without copying them. A half float
    // bitmap holds them unbounded, and an eight or sixteen bit one from 0 to 1.
    func cgImage() throws -> CGImage {
        let bitsPerComponent = depth.bitsPerComponent
        let bitmapInfo = switch depth {
        case .eight:
            CGImageAlphaInfo.premultipliedLast.rawValue

        case .sixteen:
            CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder16Little.rawValue

        case .halfFloat:
            WorkingSpace.bitmapInfo
        }
        guard
            let provider = CGDataProvider(data: pixels as CFData),
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bitsPerPixel: bitsPerComponent * 4,
                bytesPerRow: bytesPerRow,
                space: WorkingSpace.encoded,
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

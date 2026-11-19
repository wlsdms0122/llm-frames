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
    // The bitmap's pixels as a Core Graphics image in the working space, without copying them. Half floats are taken in
    // extended range sRGB, which holds values below 0 and above 1.
    func cgImage() throws -> CGImage {
        let bitsPerComponent = depth.bitsPerComponent
        let bitmapInfo = switch depth {
        case .eight:
            CGImageAlphaInfo.premultipliedLast.rawValue

        case .sixteen:
            WorkingSpace.bitmapInfo

        case .halfFloat:
            WorkingSpace.bitmapInfo | CGBitmapInfo.floatComponents.rawValue
        }
        guard
            let provider = CGDataProvider(data: pixels as CFData),
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bitsPerPixel: bitsPerComponent * 4,
                bytesPerRow: bytesPerRow,
                space: depth == .halfFloat ? CGColorSpace(name: CGColorSpace.extendedSRGB)! : WorkingSpace.colorSpace,
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

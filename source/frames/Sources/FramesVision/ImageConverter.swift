//
//  ImageConverter.swift
//  FramesVision
//
//  Created by JSilver on 11/16/26.
//

import CoreGraphics
import Foundation
import Frames

// Gives Vision a decoder's picture as an sRGB image, its pixels as they are.
struct ImageConverter: Sendable {
    // MARK: - Property
    private static let workingSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    // MARK: - Initializer
    // MARK: - Public
    func image(
        of picture: Bitmap,
        file: String,
        index: Int
    ) throws -> CGImage {
        let byteOrder: CGImageByteOrderInfo = picture.depth == .sixteen ? .order16Host : .orderDefault
        guard
            let provider = CGDataProvider(data: picture.pixels as CFData),
            let image = CGImage(
                width: picture.width,
                height: picture.height,
                bitsPerComponent: picture.depth.bitsPerComponent,
                bitsPerPixel: picture.depth.bitsPerComponent * 4,
                bytesPerRow: picture.bytesPerRow,
                space: Self.workingSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | byteOrder.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            throw VisionError.unreadablePicture(file: file, index: index)
        }

        return image
    }

    // MARK: - Private
}

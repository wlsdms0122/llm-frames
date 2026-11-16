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
        of picture: DecodedPicture,
        file: String,
        index: Int
    ) throws -> CGImage {
        let byteOrder = picture.bitsPerComponent == 16 ? CGBitmapInfo.byteOrder16Little : []
        guard
            let provider = CGDataProvider(data: picture.pixels as CFData),
            let image = CGImage(
                width: picture.width,
                height: picture.height,
                bitsPerComponent: picture.bitsPerComponent,
                bitsPerPixel: picture.bitsPerComponent * 4,
                bytesPerRow: picture.bytesPerRow,
                space: Self.workingSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).union(byteOrder),
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

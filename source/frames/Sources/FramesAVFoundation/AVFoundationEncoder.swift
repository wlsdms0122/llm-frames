//
//  AVFoundationEncoder.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/17/26.
//

import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers
import VideoToolbox
import Frames

// The `avfoundation` encoder: writes PNGs with ImageIO, and masters and deliveries with AVAssetWriter, each straight
// to its path. A PNG is 16 bits per component from a sixteen bit bitmap and 8 otherwise, its premultiplied colour
// written as PNG's straight alpha by ImageIO, with an `sRGB` chunk. A wait on a video writer longer than `deadline`
// seconds cancels it.
package final class AVFoundationEncoder: Sendable {
    // MARK: - Property
    private static let workingSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    private let deadline: Double

    // MARK: - Initializer
    package init(deadline: Double = 60) {
        self.deadline = deadline
    }

    // MARK: - Public
    // MARK: - Private
    private func image(
        of bitmap: Bitmap,
        path: String
    ) throws -> CGImage {
        let byteOrder: CGBitmapInfo = bitmap.depth == .sixteen ? .byteOrder16Little : []
        guard
            let provider = CGDataProvider(data: bitmap.pixels as CFData),
            let image = CGImage(
                width: bitmap.width,
                height: bitmap.height,
                bitsPerComponent: bitmap.depth.bitsPerComponent,
                bitsPerPixel: bitmap.depth.bitsPerComponent * 4,
                bytesPerRow: bitmap.bytesPerRow,
                space: Self.workingSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).union(byteOrder),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            throw EncoderError.unwritable(file: path, reason: "its bitmap cannot be made an image")
        }

        return image
    }

    // Whether VideoToolbox lists an encoder for `codecType`.
    private func canEncode(_ codecType: CMVideoCodecType) -> Bool {
        var list: CFArray?
        guard VTCopyVideoEncoderList(nil, &list) == noErr, let encoders = list as? [[String: Any]] else { return false }

        return encoders.contains { encoder in
            (encoder[kVTVideoEncoderList_CodecType as String] as? NSNumber)?.uint32Value == codecType
        }
    }
}

extension AVFoundationEncoder: Encoder {
    // MARK: - Lifecycle
    package func check(_ target: EncodeTarget) throws {
        let format = TargetFormat(target: target)
        guard canEncode(format.codecType) else {
            throw EncoderError.unencodable(file: format.path, codec: format.codecName)
        }
    }

    package func writeImage(
        _ bitmap: Bitmap,
        to path: String
    ) throws {
        let image = try image(of: bitmap, path: path)
        guard
            let destination = CGImageDestinationCreateWithURL(
                URL(fileURLWithPath: path) as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else {
            throw EncoderError.unwritable(file: path, reason: "ImageIO cannot open it")
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(atPath: path)
            throw EncoderError.unwritable(file: path, reason: "ImageIO cannot finish it")
        }
    }

    package func videoWriter(
        for target: EncodeTarget,
        size: Size,
        fps: Double,
        sound: SoundBuffer?
    ) throws -> any VideoWriter {
        try AssetVideoWriter(
            format: TargetFormat(target: target),
            size: size,
            fps: fps,
            sound: sound,
            deadline: deadline
        )
    }
}

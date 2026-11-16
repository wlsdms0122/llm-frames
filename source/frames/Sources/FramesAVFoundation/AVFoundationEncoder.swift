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

// The `avfoundation` encoder: writes images with ImageIO, and masters, deliveries, compressed videos and sound files
// with AVAssetWriter, each straight to its path. A PNG is 16 bits per component from a sixteen bit bitmap and 8
// otherwise, its premultiplied colour written as PNG's straight alpha by ImageIO, with an `sRGB` chunk. A JPEG or HEIC
// carries an sRGB profile. An image is scaled to its target's size by Core Graphics at high interpolation, and no
// properties but the picture's own go into it. A wait on a video or sound writer longer than `deadline` seconds
// cancels it.
package final class AVFoundationEncoder: Sendable {
    // MARK: - Property
    private static let workingSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    private let deadline: Double
    private let soundConverter = AACSoundConverter()

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
        guard let image = bitmap.image() else {
            throw EncoderError.unwritable(file: path, reason: "its bitmap cannot be made an image")
        }

        return image
    }

    // The picture at the target's size, a JPEG's over white. One of the bitmap's own size that keeps its alpha is
    // the bitmap itself.
    private func picture(
        of bitmap: Bitmap,
        for target: ImageTarget
    ) throws -> CGImage {
        let image = try image(of: bitmap, path: target.path)
        let width = Int(target.size.width)
        let height = Int(target.size.height)
        let isJPEG = if case .jpeg = target { true } else { false }
        guard isJPEG || width != bitmap.width || height != bitmap.height else { return image }

        let depth = isJPEG ? BitDepth.eight : bitmap.depth
        let byteOrder: CGBitmapInfo = depth == .sixteen ? .byteOrder16Little : []
        let alpha: CGImageAlphaInfo = isJPEG ? .noneSkipLast : .premultipliedLast
        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: depth.bitsPerComponent,
                bytesPerRow: 0,
                space: Self.workingSpace,
                bitmapInfo: CGBitmapInfo(rawValue: alpha.rawValue).union(byteOrder).rawValue
            )
        else {
            throw EncoderError.unwritable(file: target.path, reason: "it cannot be drawn at \(width)x\(height)")
        }

        let whole = CGRect(x: 0, y: 0, width: width, height: height)
        if isJPEG {
            context.setFillColor(CGColor(colorSpace: Self.workingSpace, components: [1, 1, 1, 1])!)
            context.fill(whole)
        }
        context.interpolationQuality = .high
        context.draw(image, in: whole)
        guard let drawn = context.makeImage() else {
            throw EncoderError.unwritable(file: target.path, reason: "it cannot be drawn at \(width)x\(height)")
        }

        return drawn
    }

    private func write(
        _ image: CGImage,
        type: UTType,
        properties: [CFString: Any],
        to path: String
    ) throws {
        guard
            let destination = CGImageDestinationCreateWithURL(
                URL(fileURLWithPath: path) as CFURL,
                type.identifier as CFString,
                1,
                nil
            )
        else {
            throw EncoderError.unwritable(file: path, reason: "ImageIO cannot open it")
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(atPath: path)
            throw EncoderError.unwritable(file: path, reason: "ImageIO cannot finish it")
        }
    }

    private func fileType(of target: ImageTarget) -> UTType {
        switch target {
        case .png:
            .png

        case .jpeg:
            .jpeg

        case .heic:
            .heic
        }
    }

    private func codecName(of target: ImageTarget) -> String {
        switch target {
        case .png:
            "PNG"

        case .jpeg:
            "JPEG"

        case .heic:
            "HEIC"
        }
    }

    // Whether VideoToolbox lists an encoder for `codecType`.
    private func canEncode(_ codecType: CMVideoCodecType) -> Bool {
        var list: CFArray?
        guard VTCopyVideoEncoderList(nil, &list) == noErr, let encoders = list as? [[String: Any]] else { return false }

        return encoders.contains { encoder in
            (encoder[kVTVideoEncoderList_CodecType as String] as? NSNumber)?.uint32Value == codecType
        }
    }

    // Whether Core Audio lists an encoder for AAC.
    private func canEncodeAAC() -> Bool {
        var size: UInt32 = 0
        guard AudioFormatGetPropertyInfo(kAudioFormatProperty_EncodeFormatIDs, 0, nil, &size) == noErr else {
            return false
        }
        var formats = [AudioFormatID](repeating: 0, count: Int(size) / MemoryLayout<AudioFormatID>.size)
        guard AudioFormatGetProperty(kAudioFormatProperty_EncodeFormatIDs, 0, nil, &size, &formats) == noErr else {
            return false
        }

        return formats.contains(kAudioFormatMPEG4AAC)
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

    package func check(_ target: ImageTarget) throws {
        let types = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        guard types.contains(fileType(of: target).identifier) else {
            throw EncoderError.unencodable(file: target.path, codec: codecName(of: target))
        }
    }

    package func check(_ target: SoundTarget) throws {
        guard canEncodeAAC() else {
            throw EncoderError.unencodable(file: target.path, codec: "AAC")
        }
    }

    package func writeImage(
        _ bitmap: Bitmap,
        to path: String
    ) throws {
        let size = Size(width: Double(bitmap.width), height: Double(bitmap.height))

        try writeImage(bitmap, for: .png(path: path, size: size))
    }

    package func writeImage(
        _ bitmap: Bitmap,
        for target: ImageTarget
    ) throws {
        let picture = try picture(of: bitmap, for: target)
        let properties: [CFString: Any] = switch target {
        case .png:
            [:]

        case let .jpeg(_, _, quality), let .heic(_, _, quality):
            [kCGImageDestinationLossyCompressionQuality: quality.imageQuality]
        }

        try write(picture, type: fileType(of: target), properties: properties, to: target.path)
    }

    package func writeSound(
        _ sound: SoundBuffer,
        for target: SoundTarget
    ) throws {
        let fitted = try soundConverter.fitted(sound, path: target.path)
        let settings = AACSettings(
            sampleRate: fitted.sampleRate,
            channels: fitted.channels,
            bitRate: target.quality.soundBitRate * fitted.channels
        )

        try AssetSoundWriter(path: target.path, settings: settings, deadline: deadline).write(fitted)
    }

    package func videoWriter(
        for target: EncodeTarget,
        size: Size,
        fps: Double,
        sound: SoundBuffer?
    ) throws -> any VideoWriter {
        let format = TargetFormat(target: target)
        let fitted = if case .compressed = target {
            try sound.map { try soundConverter.fitted($0, path: format.path) }
        } else {
            sound
        }

        return try AssetVideoWriter(
            format: format,
            size: size,
            fps: fps,
            sound: fitted,
            deadline: deadline
        )
    }
}

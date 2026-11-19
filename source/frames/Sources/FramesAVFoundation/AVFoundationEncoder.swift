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
// with AVAssetWriter, each straight to its path. An image's working values are scaled to its target's size by Core
// Graphics at high interpolation, encoded by its target's output (FRAMES-26 Output) and tagged with the output's
// Core Graphics space, its premultiplied colour written as straight alpha by ImageIO: a PNG at its target's depth, a
// HEIC at 16 bits in an HDR space, which ImageIO writes as 10, and at 8 in an SDR one, and a JPEG at 8 over white. A
// PNG written to a path alone is `srgb` at its bitmap's depth. No properties but the picture's own go into an image. A
// wait on a video or sound writer longer than `deadline` seconds cancels it.
package final class AVFoundationEncoder: Sendable {
    // MARK: - Property
    private let deadline: Double
    private let soundConverter = AACSoundConverter()

    // MARK: - Initializer
    package init(deadline: Double = 60) {
        self.deadline = deadline
    }

    // MARK: - Public
    // MARK: - Private
    // The bitmap at `width` by `height`, each pixel's colour converted by `conversion` and stored at `depth`, sixteen
    // bits for a half float one, as an image in `space`. An opaque image's colour is over white, which is 1 in every
    // SDR space's encoded values.
    private func image(
        of bitmap: Bitmap,
        width: Int,
        height: Int,
        depth: BitDepth,
        space: CGColorSpace,
        isOpaque: Bool,
        path: String,
        by conversion: @escaping @Sendable (RGB) -> RGB
    ) throws -> CGImage {
        guard let fitted = bitmap.scaled(width: width, height: height) else {
            throw EncoderError.unwritable(file: path, reason: "it cannot be drawn at \(width)x\(height)")
        }

        var pixels = fitted.floatPixels()
        pixels.convertColors(width: width, by: conversion)
        if isOpaque {
            for pixel in stride(from: 0, to: pixels.count, by: 4) {
                let transparency = 1 - pixels[pixel + 3]
                for channel in 0..<3 {
                    pixels[pixel + channel] += transparency
                }
                pixels[pixel + 3] = 1
            }
        }

        let isEightBits = depth == .eight
        let bytesPerRow = width * 4 * (isEightBits ? 1 : 2)
        var data = Data(count: bytesPerRow * height)
        data.withUnsafeMutableBytes { buffer in
            if isEightBits {
                let output = buffer.bindMemory(to: UInt8.self)
                for index in pixels.indices {
                    output[index] = FrameConverter.eightBits(pixels[index])
                }
            } else {
                let output = buffer.bindMemory(to: UInt16.self)
                for index in pixels.indices {
                    output[index] = FrameConverter.sixteenBits(pixels[index]).littleEndian
                }
            }
        }

        let alpha = isOpaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast
        let bitmapInfo = CGBitmapInfo(rawValue: alpha.rawValue).union(isEightBits ? [] : .byteOrder16Little)
        guard
            let provider = CGDataProvider(data: data as CFData),
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: isEightBits ? 8 : 16,
                bitsPerPixel: isEightBits ? 32 : 64,
                bytesPerRow: bytesPerRow,
                space: space,
                bitmapInfo: bitmapInfo,
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

    private func depth(of target: ImageTarget) -> BitDepth {
        switch target {
        case let .png(_, _, depth, _):
            depth

        case let .heic(_, _, _, output):
            output.space.isHighDynamicRange ? .sixteen : .eight

        case .jpeg:
            .eight
        }
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

    private func canEncode(_ codecType: CMVideoCodecType) -> Bool {
        var list: CFArray?
        guard VTCopyVideoEncoderList(nil, &list) == noErr, let encoders = list as? [[String: Any]] else { return false }

        return encoders.contains { encoder in
            (encoder[kVTVideoEncoderList_CodecType as String] as? NSNumber)?.uint32Value == codecType
        }
    }

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

    // Whether AVAssetWriter takes `settings` for sound in a file of `fileType`. The writer is made for a path in the
    // temporary directory and never started, so no file is touched.
    private func canWriteSound(
        _ settings: [String: Any],
        fileType: AVFileType
    ) -> Bool {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: fileType) else { return false }

        return writer.canApply(outputSettings: settings, forMediaType: .audio)
    }
}

extension AVFoundationEncoder: Encoder {
    // MARK: - Lifecycle
    package func check(_ target: EncodeTarget) throws {
        let format = TargetFormat(target: target)
        guard canEncode(format.codecType) else {
            throw EncoderError.unencodable(file: format.path, codec: format.codecName)
        }
        if format.codecType == kCMVideoCodecType_H264, target.output.space.isHighDynamicRange {
            throw EncoderError.highDynamicRange(file: format.path, codec: format.codecName, colorSpace: target.output.space)
        }
        if let settings = format.fixedAudioSettings, !canWriteSound(settings, fileType: format.fileType) {
            throw EncoderError.unwritable(file: format.path, reason: "its sound format is not written")
        }
    }

    package func check(_ target: ImageTarget) throws {
        let types = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        guard types.contains(fileType(of: target).identifier) else {
            throw EncoderError.unencodable(file: target.path, codec: codecName(of: target))
        }
        if case .jpeg = target, target.output.space.isHighDynamicRange {
            throw EncoderError.highDynamicRange(file: target.path, codec: "JPEG", colorSpace: target.output.space)
        }
    }

    package func check(_ target: SoundTarget) throws {
        guard canEncodeAAC() else {
            throw EncoderError.unencodable(file: target.path, codec: "AAC")
        }
        try soundConverter.check(target.layout, path: target.path)
        let settings = soundConverter.settings(for: target)
        guard canWriteSound(settings.outputSettings, fileType: .m4a) else {
            throw EncoderError.unwritable(
                file: target.path,
                reason: "AAC at \(Int(settings.sampleRate)) Hz is not written"
            )
        }
    }

    package func writeImage(
        _ bitmap: Bitmap,
        to path: String
    ) throws {
        let size = Size(width: Double(bitmap.width), height: Double(bitmap.height))

        try writeImage(bitmap, for: .png(path: path, size: size, depth: bitmap.depth == .eight ? .eight : .sixteen))
    }

    package func writeImage(
        _ bitmap: Bitmap,
        for target: ImageTarget
    ) throws {
        let output = target.output
        let isJPEG = if case .jpeg = target { true } else { false }
        let picture = try image(
            of: bitmap,
            width: Int(target.size.width),
            height: Int(target.size.height),
            depth: depth(of: target),
            space: output.space.imageSpace,
            isOpaque: isJPEG,
            path: target.path
        ) { output.output($0) }
        let properties: [CFString: Any] = switch target {
        case .png:
            [:]

        case let .jpeg(_, _, quality, _), let .heic(_, _, quality, _):
            [kCGImageDestinationLossyCompressionQuality: quality.imageQuality]
        }

        try write(picture, type: fileType(of: target), properties: properties, to: target.path)
    }

    package func writeSound(
        _ sound: SoundBuffer,
        for target: SoundTarget
    ) throws {
        let fitted = try soundConverter.fitted(sound, path: target.path)
        let settings = soundConverter.settings(for: target)

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

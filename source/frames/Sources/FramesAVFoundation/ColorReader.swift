//
//  ColorReader.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/20/26.
//

import AVFoundation
import CoreVideo
import Foundation
import Frames
import ImageIO

// Tells how a file's pictures are taken to working values from its tags. A still without a profile is `srgb`, one
// whose space `ColorSpace(imageSpace:)` recognises is that space, and one with any other profile is read by the
// platform's colour management. A video's code points name the space of the table they give, nil for a pair outside
// it, and an untagged video is `srgb`.
struct ColorReader: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Nil for a file that is neither a still nor a video.
    func colorReading(at path: String) throws -> ColorReading? {
        if
            let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
            CGImageSourceGetCount(source) > 0,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        {
            guard properties[kCGImagePropertyProfileName] != nil else { return .formulas(.srgb) }
            guard let space = CGImageSourceCreateImageAtIndex(source, 0, nil)?.colorSpace else {
                throw DecoderError.unreadable(file: path)
            }

            return ColorSpace(imageSpace: space).map(ColorReading.formulas) ?? .platform
        }

        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let waiter = LoadWaiter(file: path)
        guard let track = try waiter.tracks(of: asset, type: .video).first else { return nil }
        let format = try waiter.value(of: .formatDescriptions, key: "formatDescriptions", in: track).first
        let primaries = format.flatMap { codePoint(of: $0, key: kCVImageBufferColorPrimariesKey) {
            CVColorPrimariesGetIntegerCodePointForString($0)
        } }
        let transfer = format.flatMap { codePoint(of: $0, key: kCVImageBufferTransferFunctionKey) {
            CVTransferFunctionGetIntegerCodePointForString($0)
        } }

        return .formulas(ColorSpace(colorPrimaries: primaries, transferCharacteristics: transfer))
    }

    // MARK: - Private
    private func codePoint(
        of format: CMFormatDescription,
        key: CFString,
        _ integer: (CFString) -> Int32
    ) -> Int? {
        guard let name = CMFormatDescriptionGetExtension(format, extensionKey: key) as? String else { return nil }

        return Int(integer(name as CFString))
    }
}

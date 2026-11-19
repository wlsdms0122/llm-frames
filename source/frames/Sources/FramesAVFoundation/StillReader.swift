//
//  StillReader.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import CoreImage
import Foundation
import Frames
import ImageIO
import UniformTypeIdentifiers

// A still image file, opened once: its size as it is displayed, its bit depth, whether it carries alpha, the colour its
// ICC profile names, and its picture. An orientation that turns it a quarter swaps width and height. An image without a
// profile is untagged, and one with an sRGB chunk is given the sRGB profile.
struct StillReader {
    // MARK: - Property
    let displaySize: Size
    let bitDepth: Int
    let hasAlpha: Bool
    let isTagged: Bool

    private let source: CGImageSource
    private let orientation: CGImagePropertyOrientation

    // MARK: - Initializer
    // Nil for a file that is not an image.
    init?(path: String) throws {
        guard
            let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
            let type = CGImageSourceGetType(source).flatMap({ UTType($0 as String) }),
            type.conforms(to: .image),
            CGImageSourceGetCount(source) > 0
        else {
            return nil
        }
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Double,
            let height = properties[kCGImagePropertyPixelHeight] as? Double
        else {
            throw DecoderError.unreadable(file: path)
        }
        let orientation = (properties[kCGImagePropertyOrientation] as? UInt32)
            .flatMap(CGImagePropertyOrientation.init(rawValue:)) ?? .up

        self.source = source
        self.orientation = orientation
        self.displaySize = orientation.rawValue >= 5
            ? Size(width: height, height: width)
            : Size(width: width, height: height)
        self.bitDepth = properties[kCGImagePropertyDepth] as? Int ?? 8
        self.hasAlpha = properties[kCGImagePropertyHasAlpha] as? Bool ?? false
        self.isTagged = properties[kCGImagePropertyProfileName] != nil
    }

    // MARK: - Public
    // The picture as it is displayed, its samples as the file stores them, with no colour matched.
    func image(path: String) throws -> CIImage {
        CIImage(cgImage: try cgImage(path: path), options: [.colorSpace: NSNull()]).oriented(orientation)
    }

    func taggedColor(path: String) throws -> TaggedColor {
        let profile = isTagged ? try cgImage(path: path).colorSpace?.copyICCData() : nil

        return TaggedColor(profile: profile.map { ICCProfileReader(data: $0 as Data) }, bitDepth: bitDepth)
    }

    // MARK: - Private
    private func cgImage(path: String) throws -> CGImage {
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw DecoderError.unreadable(file: path)
        }

        return image
    }
}

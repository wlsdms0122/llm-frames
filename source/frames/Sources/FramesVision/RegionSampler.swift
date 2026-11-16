//
//  RegionSampler.swift
//  FramesVision
//
//  Created by JSilver on 11/16/26.
//

import CoreGraphics
import Foundation

// Reads a region of a picture into a grey image of a fixed size.
struct RegionSampler: Sendable {
    // MARK: - Property
    private static let space = CGColorSpaceCreateDeviceGray()

    // MARK: - Initializer
    // MARK: - Public
    // The region of `size` times `scale` media pixels centred on `centre`, drawn at `size`. Its pixels outside the
    // picture are NaN.
    func sample(
        _ image: CGImage,
        centre: CGPoint,
        size: CGSize,
        scale: Double
    ) -> GreyImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        var pixels = [UInt8](repeating: 0, count: width * height)
        let left = centre.x - size.width * scale / 2
        let top = centre.y - size.height * scale / 2
        let pictureHeight = Double(image.height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width,
                    space: Self.space,
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                )
            else {
                return false
            }
            context.interpolationQuality = .high
            // The picture is drawn so that the region's top left, in media pixels from the picture's top left, lands
            // on the context's top left, which CoreGraphics counts from the bottom.
            context.draw(
                image,
                in: CGRect(
                    x: -left / scale,
                    y: size.height - (pictureHeight - top) / scale,
                    width: Double(image.width) / scale,
                    height: pictureHeight / scale
                )
            )

            return true
        }
        guard drawn else { return nil }

        // The region's whole pixels whose area lies in the picture.
        let minX = max(0, Int((-left / scale).rounded(.up)))
        let minY = max(0, Int((-top / scale).rounded(.up)))
        let maxX = min(width, Int(((Double(image.width) - left) / scale).rounded(.down)))
        let maxY = min(height, Int(((pictureHeight - top) / scale).rounded(.down)))
        let values = pixels.indices.map { index -> Float in
            let x = index % width
            let y = index / width
            guard (minX..<max(minX, maxX)).contains(x), (minY..<max(minY, maxY)).contains(y) else { return .nan }

            return Float(pixels[index]) / 255
        }

        return GreyImage(width: width, height: height, values: values)
    }

    // MARK: - Private
}

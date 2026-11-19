//
//  Bitmap+Image.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Foundation
import Frames

// A bitmap as a Core Graphics image of working values, sharing its pixels: an integer bitmap in sRGB, a half float one
// in extended sRGB, which holds values below 0 and above 1.
extension Bitmap {
    // MARK: - Property
    private static let workingSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let extendedWorkingSpace = CGColorSpace(name: CGColorSpace.extendedSRGB)!

    private var bitmapInfo: CGBitmapInfo {
        let alpha = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        return switch depth {
        case .eight:
            alpha

        case .sixteen:
            alpha.union(.byteOrder16Little)

        case .halfFloat:
            alpha.union(.byteOrder16Little).union(.floatComponents)
        }
    }

    private var space: CGColorSpace {
        depth == .halfFloat ? Self.extendedWorkingSpace : Self.workingSpace
    }

    // MARK: - Initializer
    // MARK: - Public
    // Nil when Core Graphics cannot describe its layout.
    func image() -> CGImage? {
        guard let provider = CGDataProvider(data: pixels as CFData) else { return nil }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: depth.bitsPerComponent,
            bitsPerPixel: depth.bitsPerComponent * 4,
            bytesPerRow: bytesPerRow,
            space: space,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    // The bitmap drawn at `width` by `height` by Core Graphics at high interpolation, in its own depth and working
    // space; itself at its own size, and nil when Core Graphics cannot draw it.
    func scaled(
        width: Int,
        height: Int
    ) -> Bitmap? {
        guard width != self.width || height != self.height else { return self }
        guard
            let image = image(),
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: depth.bitsPerComponent,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: bitmapInfo.rawValue
            )
        else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }

        return Bitmap(
            width: width,
            height: height,
            depth: depth,
            bytesPerRow: context.bytesPerRow,
            pixels: Data(bytes: data, count: context.bytesPerRow * height)
        )
    }

    // Its pixels as RGBA floats with premultiplied alpha, rows top first and packed: an integer component taken to 0
    // to 1, a half float one as it is, and alpha clipped to 0 to 1.
    func floatPixels() -> [Float] {
        var floats = [Float](repeating: 0, count: width * height * 4)
        pixels.withUnsafeBytes { source in
            for row in 0..<height {
                let input = source.baseAddress! + row * bytesPerRow
                for index in 0..<width * 4 {
                    floats[row * width * 4 + index] = component(of: input, at: index)
                }
            }
        }
        for alpha in stride(from: 3, to: floats.count, by: 4) {
            floats[alpha] = min(max(floats[alpha], 0), 1)
        }

        return floats
    }

    // MARK: - Private
    private func component(
        of row: UnsafeRawPointer,
        at index: Int
    ) -> Float {
        switch depth {
        case .eight:
            Float(row.assumingMemoryBound(to: UInt8.self)[index]) / 255

        case .sixteen:
            Float(UInt16(littleEndian: row.assumingMemoryBound(to: UInt16.self)[index])) / 65_535

        case .halfFloat:
            Float(row.assumingMemoryBound(to: Float16.self)[index])
        }
    }
}

extension [Float] {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Each pixel of interleaved premultiplied RGBA unpremultiplied, converted by `conversion` and premultiplied again,
    // its alpha kept, rows of `width` pixels in parallel.
    mutating func convertColors(
        width: Int,
        by conversion: @Sendable (RGB) -> RGB
    ) {
        let rowLength = width * 4
        guard rowLength > 0 else { return }

        let rows = count / rowLength
        withUnsafeMutableBufferPointer { buffer in
            nonisolated(unsafe) let pixels = buffer
            DispatchQueue.concurrentPerform(iterations: rows) { row in
                let start = row * rowLength
                UnsafeMutableBufferPointer(rebasing: pixels[start..<start + rowLength]).convertColors(by: conversion)
            }
        }
    }

    // MARK: - Private
}

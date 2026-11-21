//
//  CornerPinStill.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// The still sources of FRAMES-24's corner pin set, 1024 × 1024 pixels, pixel (i, j) being column i and row j from the
// top left: a checkerboard of 32 px squares with a soft left edge, and an opaque black grid of white 1 px lines every
// 4 px. Each is written as a 16-bit sRGB PNG, so its pixels are the premultiplied values given, within 16-bit rounding.
enum CornerPinStill: CustomStringConvertible, Sendable {
    case checkerboard
    case grid

    // MARK: - Property
    static let side = 1024

    var description: String {
        switch self {
        case .checkerboard:
            "checkerboard"

        case .grid:
            "grid"
        }
    }

    // Premultiplied red, green, blue and alpha, rows top first.
    var pixels: [Float] {
        (0..<Self.side).flatMap { row in
            (0..<Self.side).flatMap { column in pixel(column: column, row: row) }
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    func write(to path: String) throws {
        let side = Self.side
        let values = pixels.map { UInt16(($0 * 65535).rounded()) }
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let image = values.withUnsafeBufferPointer { buffer -> CGImage? in
            guard
                let provider = CGDataProvider(data: Data(buffer: buffer) as CFData)
            else {
                return nil
            }

            return CGImage(
                width: side,
                height: side,
                bitsPerComponent: 16,
                bitsPerPixel: 64,
                bytesPerRow: side * 8,
                space: space,
                bitmapInfo: CGBitmapInfo(
                    rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder16Little.rawValue
                ),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        }
        guard
            let image,
            let destination = CGImageDestinationCreateWithURL(
                URL(fileURLWithPath: path) as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else {
            throw CocoaError(.fileWriteUnknown)
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }

    // MARK: - Private
    private func pixel(
        column: Int,
        row: Int
    ) -> [Float] {
        switch self {
        case .checkerboard:
            let color: [Float] = (column / 32 + row / 32).isMultiple(of: 2) ? [0.9, 0.25, 0.1] : [0.1, 0.35, 0.85]
            let alpha = column < 64 ? Float(Float16((Float(column) + 0.5) / 64)) : 1

            return color.map { Float(Float16($0)) * alpha } + [alpha]

        case .grid:
            let value: Float = column.isMultiple(of: 4) || row.isMultiple(of: 4) ? 1 : 0

            return [value, value, value, 1]
        }
    }
}

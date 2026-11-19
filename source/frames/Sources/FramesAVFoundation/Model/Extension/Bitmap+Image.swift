//
//  Bitmap+Image.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics
import Foundation
import Frames

// A bitmap as a Core Graphics image in the working space, sharing its pixels: sRGB for integer components, and
// extended range sRGB for half floats, which hold values below 0 and above 1.
extension Bitmap {
    // MARK: - Property
    private static let workingSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let extendedWorkingSpace = CGColorSpace(name: CGColorSpace.extendedSRGB)!

    // MARK: - Initializer
    // MARK: - Public
    // Nil when Core Graphics cannot describe its layout.
    func image() -> CGImage? {
        let byteOrder: CGBitmapInfo = switch depth {
        case .eight:
            []

        case .sixteen:
            .byteOrder16Little

        case .halfFloat:
            [.byteOrder16Little, .floatComponents]
        }
        guard let provider = CGDataProvider(data: pixels as CFData) else { return nil }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: depth.bitsPerComponent,
            bitsPerPixel: depth.bitsPerComponent * 4,
            bytesPerRow: bytesPerRow,
            space: depth == .halfFloat ? Self.extendedWorkingSpace : Self.workingSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).union(byteOrder),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    // MARK: - Private
}

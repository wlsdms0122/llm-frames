//
//  FrameConverter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/17/26.
//

import CoreVideo
import Foundation
import Frames

// Copies a bitmap into a pixel buffer of a target's pixel format, tagged BT.709 primaries, the sRGB transfer and the
// BT.709 matrix. `kCVPixelFormatType_64RGBALE` is the bitmap's own layout at sixteen bits, so values reach the codec
// unchanged. `kCVPixelFormatType_32BGRA` takes each component rounded to eight bits. A target without alpha gets
// alpha one: premultiplied colour with its alpha dropped is that colour over black.
struct FrameConverter: Sendable {
    // MARK: - Property
    private let keepsAlpha: Bool

    private var attachments: [CFString: CFString] {
        [
            kCVImageBufferColorPrimariesKey: kCVImageBufferColorPrimaries_ITU_R_709_2,
            kCVImageBufferTransferFunctionKey: kCVImageBufferTransferFunction_sRGB,
            kCVImageBufferYCbCrMatrixKey: kCVImageBufferYCbCrMatrix_ITU_R_709_2
        ]
    }

    // MARK: - Initializer
    init(keepsAlpha: Bool) {
        self.keepsAlpha = keepsAlpha
    }

    // MARK: - Public
    // `buffer` is as wide and as high as `bitmap`.
    func copy(
        _ bitmap: Bitmap,
        into buffer: CVPixelBuffer
    ) {
        for (key, value) in attachments {
            CVBufferSetAttachment(buffer, key, value, .shouldPropagate)
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let destination = CVPixelBufferGetBaseAddress(buffer)!
        let destinationBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        bitmap.pixels.withUnsafeBytes { source in
            for row in 0..<bitmap.height {
                let sourceRow = source.baseAddress! + row * bitmap.bytesPerRow
                let destinationRow = destination + row * destinationBytesPerRow

                if CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA {
                    copyRow(sourceRow, depth: bitmap.depth, width: bitmap.width, toBGRA: destinationRow)
                } else {
                    copyRow(sourceRow, depth: bitmap.depth, width: bitmap.width, toRGBA: destinationRow)
                }
            }
        }
    }

    // MARK: - Private
    private func copyRow(
        _ source: UnsafeRawPointer,
        depth: BitDepth,
        width: Int,
        toRGBA destination: UnsafeMutableRawPointer
    ) {
        let output = destination.assumingMemoryBound(to: UInt16.self)

        switch depth {
        case .sixteen:
            destination.copyMemory(from: source, byteCount: width * 8)

        case .eight:
            let input = source.assumingMemoryBound(to: UInt8.self)
            for index in 0..<width * 4 {
                output[index] = UInt16(input[index]) * 257
            }
        }
        guard !keepsAlpha else { return }

        for pixel in 0..<width {
            output[pixel * 4 + 3] = UInt16.max
        }
    }

    private func copyRow(
        _ source: UnsafeRawPointer,
        depth: BitDepth,
        width: Int,
        toBGRA destination: UnsafeMutableRawPointer
    ) {
        let output = destination.assumingMemoryBound(to: UInt8.self)

        for pixel in 0..<width {
            let red = component(of: source, depth: depth, at: pixel * 4)
            let green = component(of: source, depth: depth, at: pixel * 4 + 1)
            let blue = component(of: source, depth: depth, at: pixel * 4 + 2)
            let alpha = keepsAlpha ? component(of: source, depth: depth, at: pixel * 4 + 3) : UInt8.max
            output[pixel * 4] = blue
            output[pixel * 4 + 1] = green
            output[pixel * 4 + 2] = red
            output[pixel * 4 + 3] = alpha
        }
    }

    // Component `index` of a row, rounded to eight bits.
    private func component(
        of row: UnsafeRawPointer,
        depth: BitDepth,
        at index: Int
    ) -> UInt8 {
        switch depth {
        case .sixteen:
            let value = UInt32(row.assumingMemoryBound(to: UInt16.self)[index])

            return UInt8((value * 255 + 32_767) / 65_535)

        case .eight:
            return row.assumingMemoryBound(to: UInt8.self)[index]
        }
    }
}

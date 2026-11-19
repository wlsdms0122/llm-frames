//
//  FrameConverter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/17/26.
//

import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import Frames

// Copies a frame of working values into a pixel buffer of a target's pixel format, encoded as `output` writes it and
// tagged with its colour space's code points: each pixel's colour unpremultiplied, encoded and clipped to the space's
// gamut and peak (FRAMES-26 Output), and premultiplied again. `kCVPixelFormatType_64RGBALE` takes each component
// rounded to sixteen bits, `kCVPixelFormatType_64RGBAHalf` as a half float, and `kCVPixelFormatType_32BGRA` rounded
// to eight bits. A target without alpha gets alpha one: premultiplied colour with its alpha dropped is that colour over
// black. A frame of another size than the buffer is scaled to it first by Core Graphics at high interpolation, in its
// working space, which only a compressed target asks for.
struct FrameConverter: Sendable {
    // MARK: - Property
    private let keepsAlpha: Bool
    private let output: ColorConversion

    private var attachments: [CFString: CFString] {
        let properties = output.space.videoColorProperties

        return [
            kCVImageBufferColorPrimariesKey: properties[AVVideoColorPrimariesKey]! as CFString,
            kCVImageBufferTransferFunctionKey: properties[AVVideoTransferFunctionKey]! as CFString,
            kCVImageBufferYCbCrMatrixKey: properties[AVVideoYCbCrMatrixKey]! as CFString
        ]
    }

    // MARK: - Initializer
    init(
        keepsAlpha: Bool,
        output: ColorConversion
    ) {
        self.keepsAlpha = keepsAlpha
        self.output = output
    }

    // MARK: - Public
    // Gives whether the frame went in, which a scaled one does not when Core Graphics cannot draw it.
    @discardableResult
    func copy(
        _ frame: Bitmap,
        into buffer: CVPixelBuffer
    ) -> Bool {
        for (key, value) in attachments {
            CVBufferSetAttachment(buffer, key, value, .shouldPropagate)
        }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        guard let fitted = frame.scaled(width: width, height: height) else { return false }

        let output = output
        var pixels = fitted.floatPixels()
        pixels.convertColors(width: width) { output.output($0) }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let destination = CVPixelBufferGetBaseAddress(buffer)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let format = CVPixelBufferGetPixelFormatType(buffer)
        for row in 0..<height {
            let source = row * width * 4
            let line = destination + row * bytesPerRow

            switch format {
            case kCVPixelFormatType_32BGRA:
                store(pixels, from: source, width: width, toBGRA: line)

            case kCVPixelFormatType_64RGBAHalf:
                store(pixels, from: source, width: width, toHalfFloat: line)

            default:
                store(pixels, from: source, width: width, toRGBA: line)
            }
        }

        return true
    }

    // MARK: - Private
    private func alpha(_ value: Float) -> Float {
        keepsAlpha ? value : 1
    }

    private func store(
        _ pixels: [Float],
        from start: Int,
        width: Int,
        toRGBA destination: UnsafeMutableRawPointer
    ) {
        let output = destination.assumingMemoryBound(to: UInt16.self)
        for pixel in 0..<width {
            for channel in 0..<4 {
                let value = pixels[start + pixel * 4 + channel]
                output[pixel * 4 + channel] = Self.sixteenBits(channel == 3 ? alpha(value) : value)
            }
        }
    }

    private func store(
        _ pixels: [Float],
        from start: Int,
        width: Int,
        toHalfFloat destination: UnsafeMutableRawPointer
    ) {
        let output = destination.assumingMemoryBound(to: Float16.self)
        for pixel in 0..<width {
            for channel in 0..<4 {
                let value = pixels[start + pixel * 4 + channel]
                output[pixel * 4 + channel] = Float16(channel == 3 ? alpha(value) : value)
            }
        }
    }

    private func store(
        _ pixels: [Float],
        from start: Int,
        width: Int,
        toBGRA destination: UnsafeMutableRawPointer
    ) {
        let output = destination.assumingMemoryBound(to: UInt8.self)
        for pixel in 0..<width {
            let offset = start + pixel * 4
            output[pixel * 4] = Self.eightBits(pixels[offset + 2])
            output[pixel * 4 + 1] = Self.eightBits(pixels[offset + 1])
            output[pixel * 4 + 2] = Self.eightBits(pixels[offset])
            output[pixel * 4 + 3] = Self.eightBits(alpha(pixels[offset + 3]))
        }
    }
}

extension FrameConverter {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The nearest code value of an encoded value from 0 to 1.
    static func sixteenBits(_ value: Float) -> UInt16 {
        UInt16((min(max(value, 0), 1) * 65_535).rounded())
    }

    static func eightBits(_ value: Float) -> UInt8 {
        UInt8((min(max(value, 0), 1) * 255).rounded())
    }

    // MARK: - Private
}

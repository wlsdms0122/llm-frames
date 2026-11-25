//
//  MetalFrameConverterTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/25/26.
//

import CoreVideo
import Foundation
import Frames
@testable import FramesAVFoundation
import IOSurface
import Metal
import Testing

// The encoder's conversion of a surface on the GPU against `FrameConverter`'s of the same frame on the CPU, the
// reference (FRAMES-24 Tolerances).
@Suite(
    "MetalFrameConverter Tests",
    .enabled(if: MTLCreateSystemDefaultDevice() != nil, "the GPU conversion needs a Metal device")
)
struct MetalFrameConverterTests {
    // MARK: - Property
    private static let width = 512
    private static let height = 96

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a frame converted on the GPU has every code value within one of the CPU's, and the same bytes converted again",
        arguments: [ColorSpace.srgb, .displayP3, .rec2020, .rec709],
        [kCVPixelFormatType_32BGRA, kCVPixelFormatType_64RGBALE]
    )
    func convertsWithinOneCodeValue(
        colorSpace: ColorSpace,
        pixelFormat: OSType
    ) throws {
        for keepsAlpha in [true, false] {
            // Given
            let output = ColorConversion(space: colorSpace)
            let frame = try Self.frame()
            let reference = FrameConverter(keepsAlpha: keepsAlpha, output: output)
            let sut = try #require(MetalFrameConverter(output: output, keepsAlpha: keepsAlpha, pixelFormat: pixelFormat))
            let expected = try Self.pixelBuffer(format: pixelFormat)
            let converted = try Self.pixelBuffer(format: pixelFormat)
            let again = try Self.pixelBuffer(format: pixelFormat)

            // When
            reference.copy(frame.bitmap, into: expected)
            let isConverted = sut.copy(frame, into: converted)
            let isConvertedAgain = sut.copy(frame, into: again)

            // Then
            #expect(isConverted && isConvertedAgain)
            let codes = Self.codes(of: converted, format: pixelFormat)
            let expectedCodes = Self.codes(of: expected, format: pixelFormat)
            let differences = zip(codes, expectedCodes).map { abs($0 - $1) }
            let largest = differences.max() ?? 0
            let differing = differences.filter { $0 > 0 }.count
            let name = "\(colorSpace.rawValue) \(pixelFormat) alpha \(keepsAlpha)"
            print("output \(name): largest \(largest), differing \(differing) of \(codes.count)")
            #expect(largest <= 1, "\(name): largest \(largest)")
            #expect(Self.codes(of: again, format: pixelFormat) == codes)
        }
    }

    @Test("a format the GPU does not write, and an HDR output, have no GPU converter")
    func refusesOtherOutputs() {
        // Given
        let hdr = ColorConversion(space: .rec2100PQ)
        let sdr = ColorConversion(space: .srgb)

        // When
        let converters = [
            MetalFrameConverter(output: hdr, keepsAlpha: false, pixelFormat: kCVPixelFormatType_64RGBALE),
            MetalFrameConverter(output: sdr, keepsAlpha: false, pixelFormat: kCVPixelFormatType_64RGBAHalf)
        ]

        // Then
        #expect(converters.allSatisfy { $0 == nil })
    }

    // MARK: - Private
    // A surface whose pixels run over unpremultiplied colours from -0.25 to 1.25 across the row, a different phase on
    // each channel, at alphas of 0, 1/255, 0.25, 0.5, 0.9 and 1 down the rows, premultiplied and stored as half floats.
    private static func frame() throws -> PictureSurface {
        let alphas: [Float] = [0, 1 / 255, 0.25, 0.5, 0.9, 1]
        let (surface, picture) = try #require(SurfacePool().surface(width: width, height: height))
        IOSurfaceLock(surface, [], nil)
        defer { IOSurfaceUnlock(surface, [], nil) }

        let base = IOSurfaceGetBaseAddress(surface)
        let bytesPerRow = IOSurfaceGetBytesPerRow(surface)
        for y in 0..<height {
            let row = (base + y * bytesPerRow).assumingMemoryBound(to: Float16.self)
            let alpha = alphas[y * alphas.count / height]
            for x in 0..<width {
                let t = Float(x) / Float(width - 1)
                let colour = [t, (t * 3 + Float(y) / Float(height)).truncatingRemainder(dividingBy: 1), 1 - t]
                for channel in 0..<3 {
                    row[x * 4 + channel] = Float16((colour[channel] * 1.5 - 0.25) * alpha)
                }
                row[x * 4 + 3] = Float16(alpha)
            }
        }

        return picture
    }

    private static func pixelBuffer(format: OSType) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferIOSurfacePropertiesKey: [String: Any](),
            kCVPixelBufferMetalCompatibilityKey: true
        ] as CFDictionary
        let status = CVPixelBufferCreate(nil, width, height, format, attributes, &buffer)

        return try #require(status == kCVReturnSuccess ? buffer : nil)
    }

    // The buffer's code values, rows packed, each as stored: eight bits in blue, green, red, alpha order, or sixteen.
    private static func codes(
        of buffer: CVPixelBuffer,
        format: OSType
    ) -> [Int] {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let base = CVPixelBufferGetBaseAddress(buffer)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        return (0..<height).flatMap { y -> [Int] in
            let row = base + y * bytesPerRow
            switch format {
            case kCVPixelFormatType_32BGRA:
                let values = row.assumingMemoryBound(to: UInt8.self)

                return (0..<width * 4).map { Int(values[$0]) }

            default:
                let values = row.assumingMemoryBound(to: UInt16.self)

                return (0..<width * 4).map { Int(UInt16(littleEndian: values[$0])) }
            }
        }
    }
}

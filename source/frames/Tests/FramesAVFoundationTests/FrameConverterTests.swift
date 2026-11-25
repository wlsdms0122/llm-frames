//
//  FrameConverterTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/17/26.
//

import AVFoundation
import CoreVideo
import Foundation
import Frames
@testable import FramesAVFoundation
import Testing

@Suite("FrameConverter Tests")
struct FrameConverterTests {
    // MARK: - Property
    // Half transparent red, transparent, and opaque grey, premultiplied.
    private let components: [UInt16] = [32_768, 0, 0, 32_768, 0, 0, 0, 0, 30_000, 30_000, 30_000, 65_535]

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a sixteen bit bitmap reaches a 16-bit RGBA buffer unchanged, its alpha kept or set to one",
        arguments: [true, false]
    )
    func copiesSixteenBitRGBA(keepsAlpha: Bool) throws {
        // Given
        let sut = FrameConverter(keepsAlpha: keepsAlpha, output: ColorConversion(space: .srgb))
        let buffer = try pixelBuffer(format: kCVPixelFormatType_64RGBALE, width: 3)

        // When
        sut.copy(bitmap(components), into: buffer)

        // Then
        let expected = keepsAlpha
            ? components
            : [32_768, 0, 0, 65_535, 0, 0, 0, 65_535, 30_000, 30_000, 30_000, 65_535]
        #expect(read(buffer, as: UInt16.self, count: 12) == expected)
        let tags = [
            kCVImageBufferColorPrimariesKey: kCVImageBufferColorPrimaries_ITU_R_709_2,
            kCVImageBufferTransferFunctionKey: kCVImageBufferTransferFunction_sRGB,
            kCVImageBufferYCbCrMatrixKey: kCVImageBufferYCbCrMatrix_ITU_R_709_2
        ]
        for (key, value) in tags {
            #expect(attachment(key, of: buffer) == value as String)
        }
    }

    @Test("a BGRA buffer takes each component rounded to eight bits, opaque, which is the colour over black")
    func copiesOverBlackToBGRA() throws {
        // Given
        let sut = FrameConverter(keepsAlpha: false, output: ColorConversion(space: .srgb))
        let buffer = try pixelBuffer(format: kCVPixelFormatType_32BGRA, width: 3)

        // When
        sut.copy(bitmap(components), into: buffer)

        // Then
        let grey = UInt8((30_000.0 * 255 / 65_535).rounded())
        #expect(read(buffer, as: UInt8.self, count: 12) == [0, 0, 128, 255, 0, 0, 0, 255, grey, grey, grey, 255])
    }

    @Test(
        "a BGRA row of runs, single and alternating pixels takes the bytes of each pixel copied alone",
        arguments: [(ColorSpace.srgb, true), (.srgb, false), (.displayP3, true), (.rec2020, false)]
    )
    func copiesRowToBGRAAsPixelsAlone(
        space: ColorSpace,
        keepsAlpha: Bool
    ) throws {
        // Given
        let sut = FrameConverter(keepsAlpha: keepsAlpha, output: ColorConversion(space: space))
        let white: [UInt16] = [65_535, 65_535, 65_535, 65_535]
        let grey: [UInt16] = [30_000, 30_000, 30_000, 65_535]
        let halfGrey: [UInt16] = [15_000, 15_000, 15_000, 32_768]
        let red: [UInt16] = [40_000, 2_000, 1_000, 65_535]
        let clear: [UInt16] = [0, 0, 0, 0]
        let pixels = [white, white, white, red, grey, halfGrey, halfGrey, red, grey, red, grey, clear, clear, white]
        let row = Array(pixels.joined())
        let buffer = try pixelBuffer(format: kCVPixelFormatType_32BGRA, width: pixels.count)

        // When
        sut.copy(bitmap(row), into: buffer)

        // Then
        let alone = try pixels.flatMap { pixel in
            let single = try pixelBuffer(format: kCVPixelFormatType_32BGRA, width: 1)
            sut.copy(bitmap(pixel), into: single)

            return read(single, as: UInt8.self, count: 4)
        }
        #expect(read(buffer, as: UInt8.self, count: row.count) == alone)
    }

    @Test(
        "a half float buffer takes each component encoded in the output's HDR space and its code points",
        arguments: [(ColorSpace.rec2100PQ, 0.5806), (.rec2100HLG, 0.75)]
    )
    func copiesHighDynamicRangeToHalfFloat(
        space: ColorSpace,
        white: Double
    ) throws {
        // Given
        let sut = FrameConverter(keepsAlpha: false, output: ColorConversion(space: space))
        let buffer = try pixelBuffer(format: kCVPixelFormatType_64RGBAHalf, width: 3)

        // When
        sut.copy(bitmap([65_535, 65_535, 65_535, 65_535, 0, 0, 0, 0, 0, 0, 0, 65_535]), into: buffer)

        // Then
        let components = read(buffer, as: Float16.self, count: 4).map(Double.init)
        #expect(components.prefix(3).allSatisfy { abs($0 - white) < 0.002 })
        #expect(components[3] == 1)
        let properties = space.videoColorProperties
        #expect(attachment(kCVImageBufferColorPrimariesKey, of: buffer) == properties[AVVideoColorPrimariesKey])
        #expect(attachment(kCVImageBufferTransferFunctionKey, of: buffer) == properties[AVVideoTransferFunctionKey])
        #expect(attachment(kCVImageBufferYCbCrMatrixKey, of: buffer) == properties[AVVideoYCbCrMatrixKey])
    }

    // MARK: - Private
    private func bitmap(_ components: [UInt16]) -> Bitmap {
        Bitmap(
            width: components.count / 4,
            height: 1,
            depth: .sixteen,
            bytesPerRow: components.count * 2,
            pixels: components.withUnsafeBytes { Data($0) }
        )
    }

    private func pixelBuffer(
        format: OSType,
        width: Int
    ) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, width, 1, format, nil, &buffer)

        return try #require(buffer)
    }

    private func read<Component>(
        _ buffer: CVPixelBuffer,
        as type: Component.Type,
        count: Int
    ) -> [Component] {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: Component.self)

        return Array(UnsafeBufferPointer(start: base, count: count))
    }

    private func attachment(
        _ key: CFString,
        of buffer: CVPixelBuffer
    ) -> String? {
        CVBufferCopyAttachment(buffer, key, nil) as? String
    }
}

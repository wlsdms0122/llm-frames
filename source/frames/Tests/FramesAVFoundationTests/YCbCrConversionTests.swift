//
//  YCbCrConversionTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/26/26.
//

import AVFoundation
import CoreVideo
import Foundation
import Frames
@testable import FramesAVFoundation
import FramesTestMedia
import Metal
import Testing

// The decoder's own conversion of a video's Y'CbCr to R'G'B' (FRAMES-21 Rules), on the CPU, which is the reference,
// and on the GPU against it (FRAMES-24 Tolerances). Serialized, so that the tests running at once read far fewer files
// with AVFoundation than the 64 at once at which its reads stop finishing (FRAMES-21 Notes).
@Suite("Y'CbCr Conversion Tests", .serialized, .ownThread)
struct YCbCrConversionTests {
    // MARK: - Property
    // The tolerance of a working value converted on the GPU against the same one converted on the CPU (FRAMES-24
    // Tolerances): each component within `largest` × max(1, |v|), and their mean difference within `mean`.
    private static let largest = 0x1p-10
    private static let mean = 0x1p-18

    private static let left = SIMD2(0.5, 1.0)
    private static let center = SIMD2(1.0, 1.0)
    private static let topLeft = SIMD2(0.5, 0.5)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a code value is taken to R'G'B' by the range the stream names and the matrix's constants")
    func takesCodeValuesByRangeAndMatrix() {
        // Given
        let narrow = Self.layout(bitDepth: 8, sampling: .fourTwoZero, isFullRange: false)
        let full = Self.layout(bitDepth: 10, sampling: .fourTwoZero, isFullRange: true)

        // When
        let white = narrow.encoded(luma: 235, blue: 128, red: 128)
        let black = narrow.encoded(luma: 16, blue: 128, red: 128)
        let red = narrow.encoded(luma: 16, blue: 128, red: 240)
        let beyond = narrow.encoded(luma: 254, blue: 128, red: 128)
        let fullWhite = full.encoded(luma: 1023, blue: 512, red: 512)

        // Then
        #expect(abs(white.red - 1) < 1e-12 && abs(white.green - 1) < 1e-12 && abs(white.blue - 1) < 1e-12)
        #expect(abs(black.red) < 1e-12 && abs(black.green) < 1e-12 && abs(black.blue) < 1e-12)
        #expect(abs(red.red - 2 * (1 - 0.2126) * 0.5) < 1e-12)
        #expect(abs(red.green - -0.2126 * red.red / 0.7152) < 1e-12)
        #expect(abs(beyond.red - 238.0 / 219) < 1e-12)
        #expect(abs(fullWhite.red - 1) < 1e-12 && abs(fullWhite.blue - 1) < 1e-12)
    }

    @Test(
        "the 75% colour bars and 100% white of 8-bit narrow range Y'CbCr are given on the CPU and the GPU as the BT.709 and BT.601 formulas take their code values",
        arguments: [
            (
                0.2126,
                0.0722,
                [(235, 128, 128), (180, 128, 128), (168, 44, 136), (145, 147, 44), (133, 63, 52), (63, 193, 204),
                 (51, 109, 212), (28, 212, 120), (16, 128, 128)]
            ),
            (
                0.299,
                0.114,
                [(235, 128, 128), (180, 128, 128), (162, 44, 142), (131, 156, 44), (112, 72, 58), (84, 184, 198),
                 (65, 100, 212), (35, 212, 114), (16, 128, 128)]
            )
        ]
    )
    func givesColourBarsByFormula(
        lumaRed: Double,
        lumaBlue: Double,
        bars: [(Int, Int, Int)]
    ) throws {
        // Given
        let layout = YCbCrLayout(
            bitDepth: 8,
            sampling: .fourTwoZero,
            isFullRange: false,
            lumaRed: lumaRed,
            lumaBlue: lumaBlue,
            chromaSiting: Self.left
        )
        let width = bars.count * 16
        let buffer = try Self.buffer(of: layout, width: width, height: 4) { x, _ in
            bars[x / 16].0
        } chroma: { x, _, component in
            component == 0 ? bars[x / 8].1 : bars[x / 8].2
        }
        let expected = bars.map { luma, blue, red -> [Double] in
            let y = (Double(luma) - 16) / 219
            let cb = (Double(blue) - 128) / 224
            let cr = (Double(red) - 128) / 224
            let r = y + 2 * (1 - lumaRed) * cr
            let b = y + 2 * (1 - lumaBlue) * cb

            return [r, (y - lumaRed * r - lumaBlue * b) / (1 - lumaRed - lumaBlue), b]
        }

        // When
        let samples = layout.encodedSamples(of: buffer)
        let converted = try MetalPictureConverter().flatMap { sut in
            try sut.picture(
                from: buffer,
                format: .yCbCr(layout),
                storedSize: CGSize(width: width, height: 4),
                displaySize: Size(width: Double(width), height: 4),
                transform: .identity,
                steps: MediaColorConversion(.space(.srgb)).steps
            )
        }

        // Then
        #expect(expected.first == [1, 1, 1])
        for (bar, values) in expected.enumerated() {
            let pixel = (1 * width + bar * 16 + 8) * 4
            for channel in 0..<3 {
                let value = Double(samples[pixel + channel])
                #expect(abs(value - values[channel]) <= 1e-7, "bar \(bar) channel \(channel)")
            }
        }
        guard let converted else { return }
        let bitmap = converted.bitmap
        bitmap.pixels.withUnsafeBytes { bytes in
            let halves = bytes.bindMemory(to: Float16.self)
            for (bar, values) in expected.enumerated() {
                for channel in 0..<3 {
                    let value = Double(halves[1 * bitmap.bytesPerRow / 2 + (bar * 16 + 8) * 4 + channel])
                    let bound = Self.largest * max(1, abs(values[channel]))
                    #expect(abs(value - values[channel]) <= bound, "bar \(bar) channel \(channel)")
                }
            }
        }
    }

    @Test(
        "chroma is taken at each pixel's centre by straight lines between the samples where the chroma location puts them",
        arguments: [
            (left, [100.0, 150, 200, 200], [100.0, 125, 175, 200]),
            (center, [100.0, 125, 175, 200], [100.0, 125, 175, 200]),
            (topLeft, [100.0, 150, 200, 200], [100.0, 150, 200, 200])
        ]
    )
    func upsamplesChromaBilinearly(
        siting: SIMD2<Double>,
        blueAcross: [Double],
        redDown: [Double]
    ) throws {
        // Given
        let sut = Self.layout(bitDepth: 8, sampling: .fourTwoZero, isFullRange: false, siting: siting)
        let buffer = try Self.buffer(of: sut, width: 4, height: 4) { _, _ in 126 } chroma: { x, y, component in
            component == 0 ? (x == 0 ? 100 : 200) : (y == 0 ? 100 : 200)
        }

        // When
        let samples = sut.encodedSamples(of: buffer)

        // Then
        for x in 0..<4 {
            let expected = sut.encoded(luma: 126, blue: blueAcross[x], red: 150)
            let pixel = (1 * 4 + x) * 4
            #expect(abs(Double(samples[pixel + 2]) - expected.blue) < 1e-6, "x \(x)")
        }
        for y in 0..<4 {
            let expected = sut.encoded(luma: 126, blue: 150, red: redDown[y])
            let pixel = (y * 4 + 1) * 4
            #expect(abs(Double(samples[pixel]) - expected.red) < 1e-6, "y \(y)")
        }
    }

    @Test(
        "Y'CbCr of each depth, chroma sampling and range converted on the GPU lies within the tolerance of the CPU's",
        .enabled(if: MTLCreateSystemDefaultDevice() != nil, "the GPU conversion needs a Metal device"),
        arguments: [
            (8, ChromaSampling.fourTwoZero, false, left),
            (10, .fourTwoZero, true, center),
            (8, .fourTwoTwo, true, left),
            (10, .fourTwoTwo, false, center),
            (8, .fourFourFour, false, topLeft),
            (10, .fourFourFour, true, topLeft)
        ]
    )
    func convertsWithinTolerance(
        bitDepth: Int,
        sampling: ChromaSampling,
        isFullRange: Bool,
        siting: SIMD2<Double>
    ) throws {
        // Given
        let layout = Self.layout(bitDepth: bitDepth, sampling: sampling, isFullRange: isFullRange, siting: siting)
        let width = 96
        let height = 64
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        let code = { () -> Int in
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int(seed >> 33) % (1 << bitDepth)
        }
        let buffer = try Self.buffer(of: layout, width: width, height: height) { _, _ in code() } chroma: { _, _, _ in
            code()
        }
        let conversion = MediaColorConversion(.space(.displayP3))
        let sut = try #require(MetalPictureConverter())

        // When
        let converted = try #require(sut.picture(
            from: buffer,
            format: .yCbCr(layout),
            storedSize: CGSize(width: width, height: height),
            displaySize: Size(width: Double(width), height: Double(height)),
            transform: .identity,
            steps: conversion.steps
        ))
        var expected = layout.encodedSamples(of: buffer)
        expected.convertColors(width: width) { conversion.working($0) }

        // Then
        let pixels = converted.bitmap.pixels
        var largest = 0.0
        var sum = 0.0
        pixels.withUnsafeBytes { bytes in
            let halves = bytes.bindMemory(to: Float16.self)
            for row in 0..<height {
                for index in 0..<width * 4 {
                    let value = Double(Float16(expected[row * width * 4 + index]))
                    let difference = abs(Double(halves[row * converted.bitmap.bytesPerRow / 2 + index]) - value)
                    largest = max(largest, difference / max(1, abs(value)))
                    sum += difference
                }
            }
        }
        let mean = sum / Double(width * height * 4)
        #expect(largest <= Self.largest, "\(largest)")
        #expect(mean <= Self.mean, "\(mean)")
    }

    @Test(
        "a video is given in the Y'CbCr its stream stores, and a video with alpha as half floats",
        arguments: [
            (AVVideoCodecType.h264, ColorSpace.srgb, "8-bit integer Y'CbCr 4:2:0"),
            (.hevc, .displayP3, "10-bit integer Y'CbCr 4:2:0"),
            (.proRes422, .rec709, "10-bit integer Y'CbCr 4:2:2"),
            (.proRes4444, .rec709, "16-bit float RGBA")
        ]
    )
    func givesStoredFormat(
        codec: AVVideoCodecType,
        colorSpace: ColorSpace,
        pixelFormat: String
    ) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("video.mov")
        try await ColorMovieWriter(size: Size(width: 64, height: 48), colorSpace: colorSpace, codec: codec)
            .write(to: file, red: 0.5, green: 0.25, blue: 0.75)
        let sut = AVFoundationDecoder(conversion: .cpu)

        // When
        _ = try sut.picture(of: MediaFile.video(file, frameTimes: [0]), atFrame: 0, reading: .tagged)

        // Then
        #expect(sut.readings().media.first?.pixelFormat == pixelFormat)
    }

    @Test(
        "a ProRes 422 video's frames converted on the GPU lie within the tolerance of those converted on the CPU",
        .enabled(if: MTLCreateSystemDefaultDevice() != nil, "the GPU conversion needs a Metal device")
    )
    func convertsProResWithinTolerance() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("prores.mov")
        try await ColorMovieWriter(size: Size(width: 320, height: 180), colorSpace: .rec709, codec: .proRes422)
            .write(to: file, frames: 1) { _, x, y in (Double(x) / 319, Double(y) / 179, x < 160 ? 0.1 : 0.9) }
        let media = MediaFile.video(file, frameTimes: [0])

        // When
        let converted = try AVFoundationDecoder(conversion: .gpu).picture(of: media, atFrame: 0, reading: .tagged)
        let expected = try AVFoundationDecoder(conversion: .cpu).picture(of: media, atFrame: 0, reading: .tagged)

        // Then
        guard case .surface = converted else {
            Issue.record("the frame was not converted on the GPU")
            return
        }
        let difference = Self.difference(of: converted.bitmap, from: expected.bitmap)
        #expect(difference.largest <= Self.largest, "\(difference.largest)")
        #expect(difference.mean <= Self.mean, "\(difference.mean)")
    }

    @Test(
        "an H.264 stream's depth and chroma sampling are its first sequence parameter set's",
        arguments: [
            (
                [1, 244, 0, 60, 255, 225, 0, 17, 39, 244, 0, 60, 174, 86, 80, 19, 0, 82, 121, 170, 106, 24, 26, 2, 4, 1,
                 0, 4, 40, 206, 60, 176] as [UInt8],
                "8-bit integer Y'CbCr 4:2:0"
            ),
            (
                [1, 100, 0, 40, 255, 225, 0, 12, 39, 100, 0, 40, 172, 86, 80, 30, 0, 137, 249, 80, 1, 0, 4, 40, 206, 60,
                 128],
                "8-bit integer Y'CbCr 4:2:0"
            ),
            ([1, 122, 0, 40, 255, 225, 0, 6, 39, 122, 0, 40, 0xB6, 0xE0, 1, 0, 1, 40], "10-bit integer Y'CbCr 4:2:2"),
            ([1, 244, 0, 0, 255, 225, 0, 7, 39, 244, 0, 0, 3, 0xB6, 0xE0, 1, 0, 1, 40], "10-bit integer Y'CbCr 4:2:2"),
            ([1, 244, 0, 40, 255, 225, 0, 6, 39, 244, 0, 40, 0x91, 0x80, 1, 0, 1, 40], "8-bit integer Y'CbCr 4:4:4"),
            ([1, 77, 0, 40, 255, 225, 0, 5, 39, 77, 0, 40, 0x80, 1, 0, 1, 40], "8-bit integer Y'CbCr 4:2:0")
        ]
    )
    func readsSequenceParameterSet(
        avcC: [UInt8],
        name: String
    ) throws {
        // Given
        var format: CMVideoFormatDescription?
        let extensions = [
            kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: ["avcC": Data(avcC)]
        ] as CFDictionary
        CMVideoFormatDescriptionCreate(
            allocator: nil,
            codecType: kCMVideoCodecType_H264,
            width: 64,
            height: 48,
            extensions: extensions,
            formatDescriptionOut: &format
        )

        // When
        let sut = YCbCrLayout(format: try #require(format), matrix: 1, hasAlpha: false)

        // Then
        #expect(sut?.name == name)
    }

    @Test("an H.264 stream of 12 bits a sample, or of luma and chroma of two depths, is given as half floats")
    func refusesOtherDepths() throws {
        // Given
        let sets: [[UInt8]] = [
            [1, 244, 0, 40, 255, 225, 0, 6, 39, 244, 0, 40, 0xA2, 0x94, 1, 0, 1, 40],
            [1, 122, 0, 40, 255, 225, 0, 6, 39, 122, 0, 40, 0xB7, 0x80, 1, 0, 1, 40]
        ]

        // When
        let layouts = try sets.map { avcC in
            var format: CMVideoFormatDescription?
            let extensions = [
                kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms: ["avcC": Data(avcC)]
            ] as CFDictionary
            CMVideoFormatDescriptionCreate(
                allocator: nil,
                codecType: kCMVideoCodecType_H264,
                width: 64,
                height: 48,
                extensions: extensions,
                formatDescriptionOut: &format
            )

            return YCbCrLayout(format: try #require(format), matrix: 1, hasAlpha: false)
        }

        // Then
        #expect(layouts.allSatisfy { $0 == nil })
    }

    // MARK: - Private
    private static func layout(
        bitDepth: Int,
        sampling: ChromaSampling,
        isFullRange: Bool,
        siting: SIMD2<Double> = left
    ) -> YCbCrLayout {
        YCbCrLayout(
            bitDepth: bitDepth,
            sampling: sampling,
            isFullRange: isFullRange,
            lumaRed: 0.2126,
            lumaBlue: 0.0722,
            chromaSiting: SIMD2(
                sampling.horizontal == 1 ? 0.5 : siting.x,
                sampling.vertical == 1 ? 0.5 : siting.y
            )
        )
    }

    // A buffer of the layout's pixel format on a surface, its luma code values `luma(x, y)` and its chroma sample
    // (x, y)'s Cb (component 0) and Cr (component 1) `chroma(x, y, component)`.
    private static func buffer(
        of layout: YCbCrLayout,
        width: Int,
        height: Int,
        luma: (_ x: Int, _ y: Int) -> Int,
        chroma: (_ x: Int, _ y: Int, _ component: Int) -> Int
    ) throws -> CVPixelBuffer {
        var created: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        let status = CVPixelBufferCreate(
            nil,
            width,
            height,
            layout.pixelFormat,
            attributes as CFDictionary,
            &created
        )
        let buffer = try #require(status == kCVReturnSuccess ? created : nil)

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let store = { (plane: Int, x: Int, y: Int, value: Int) in
            let base = CVPixelBufferGetBaseAddressOfPlane(buffer, plane)!
            let row = CVPixelBufferGetBytesPerRowOfPlane(buffer, plane)
            if layout.bitDepth > 8 {
                base.storeBytes(of: UInt16(value << 6), toByteOffset: y * row + x * 2, as: UInt16.self)
            } else {
                base.storeBytes(of: UInt8(value), toByteOffset: y * row + x, as: UInt8.self)
            }
        }
        for y in 0..<height {
            for x in 0..<width {
                store(0, x, y, luma(x, y))
            }
        }
        for y in 0..<CVPixelBufferGetHeightOfPlane(buffer, 1) {
            for x in 0..<CVPixelBufferGetWidthOfPlane(buffer, 1) {
                store(1, x * 2, y, chroma(x, y, 0))
                store(1, x * 2 + 1, y, chroma(x, y, 1))
            }
        }

        return buffer
    }

    // The largest difference of a component from the reference's v, over max(1, |v|), and the mean difference of
    // every component, rows of each bitmap read at its own bytes per row.
    private static func difference(
        of bitmap: Bitmap,
        from reference: Bitmap
    ) -> (largest: Double, mean: Double) {
        var largest = 0.0
        var sum = 0.0
        let rowLength = bitmap.width * 4
        bitmap.pixels.withUnsafeBytes { converted in
            reference.pixels.withUnsafeBytes { expected in
                for row in 0..<bitmap.height {
                    let left = converted.baseAddress!.advanced(by: row * bitmap.bytesPerRow)
                        .assumingMemoryBound(to: Float16.self)
                    let right = expected.baseAddress!.advanced(by: row * reference.bytesPerRow)
                        .assumingMemoryBound(to: Float16.self)
                    for index in 0..<rowLength {
                        let value = Double(right[index])
                        let difference = abs(Double(left[index]) - value)
                        largest = max(largest, difference / max(1, abs(value)))
                        sum += difference
                    }
                }
            }
        }

        return (largest, sum / Double(rowLength * bitmap.height))
    }
}

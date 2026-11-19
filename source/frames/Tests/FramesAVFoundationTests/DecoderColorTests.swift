//
//  DecoderColorTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/20/26.
//

import CoreGraphics
import Foundation
import Frames
import FramesAVFoundation
import FramesTestMedia
import Testing

// Serialized, since AVAssetReader needs a free thread of the shared pool, which tests reading video at once can
// all hold.
@Suite("Decoder Colour Tests", .serialized)
struct DecoderColorTests {
    // MARK: - Property
    // P3 red, (1, 0, 0) in Display P3, in extended sRGB (FRAMES-26 Colour spaces).
    private static let displayP3Red = [1.0931, -0.2267, -0.1501]

    private let size = Size(width: 64, height: 64)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a tagged video reads to the working values of its space, reference white of PQ and HLG to 1",
        arguments: [
            (ColorSpace.srgb, [0.5, 0.25, 0.75], [0.5, 0.25, 0.75], 0.015),
            (.rec709, [0.5, 0.5, 0.5], [0.4735, 0.4735, 0.4735], 0.01),
            (.displayP3, [1, 0, 0], displayP3Red, 0.01),
            (.rec2100PQ, [0.58069, 0.58069, 0.58069], [1, 1, 1], 0.01),
            (.rec2100HLG, [0.75, 0.75, 0.75], [1, 1, 1], 0.01)
        ]
    )
    func readsTaggedVideo(
        colorSpace: ColorSpace,
        encoded: [Double],
        working: [Double],
        tolerance: Double
    ) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("\(colorSpace.rawValue).mov")
        try await ColorMovieWriter(size: size, colorSpace: colorSpace)
            .write(to: file, red: encoded[0], green: encoded[1], blue: encoded[2])
        let sut = AVFoundationDecoder()

        // When
        let picture = try sut.picture(of: MediaFile(path: file), atFrame: 0, reading: .tagged)

        // Then
        let value = workingValue(in: picture, x: 32, y: 32)
        #expect(picture.depth == .halfFloat)
        #expect(zip(value, working + [1]).allSatisfy { abs($0 - $1) <= tolerance }, "\(value)")
    }

    @Test(
        "a still tagged by an ICC profile of the table reads to the working values of its space",
        arguments: [
            (CGColorSpace.sRGB as String, [UInt8(128), 64, 192], [128.0 / 255, 64.0 / 255, 192.0 / 255]),
            (CGColorSpace.displayP3 as String, [255, 0, 0], displayP3Red)
        ]
    )
    func readsTaggedStill(
        name: String,
        codeValues: [UInt8],
        working: [Double]
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("still.png")
        try ColorImageWriter(size: size, colorSpace: try #require(CGColorSpace(name: name as CFString)))
            .write(to: file, codeValues: codeValues)
        let sut = AVFoundationDecoder()

        // When
        let picture = try sut.picture(of: MediaFile(path: file), atFrame: 0, reading: .tagged)

        // Then
        let value = workingValue(in: picture, x: 32, y: 32)
        #expect(zip(value, working + [1]).allSatisfy { abs($0 - $1) <= 0.002 }, "\(value)")
    }

    @Test("a still tagged by a gamma 2.4 BT.709 profile reads as rec709")
    func readsRec709Still() throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("still.png")
        let space = try #require(Self.rec709Profile())
        try ColorImageWriter(size: size, colorSpace: space).write(to: file, codeValues: [128, 128, 128])
        let sut = AVFoundationDecoder()

        // When
        let probed = try #require(try sut.probedMedia(of: file))
        let picture = try sut.picture(of: MediaFile(path: file), atFrame: 0, reading: .tagged)

        // Then
        let expected = TransferFunction.sRGB.encode(pow(128.0 / 255, 2.4))
        let value = workingValue(in: picture, x: 32, y: 32)
        #expect(probed.colorSpace?.name == .rec709)
        #expect(value.prefix(3).allSatisfy { abs($0 - expected) <= 0.002 }, "\(value)")
    }

    @Test("a PQ picture of 1000 cd/m² read for an SDR target is tone mapped as `ToneMapping` maps it")
    func toneMapsIntoTarget() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("bright.mov")
        let encoded = PerceptualQuantizer().encoded(displayLight: 1000)
        try await ColorMovieWriter(size: size, colorSpace: .rec2100PQ)
            .write(to: file, red: encoded, green: encoded, blue: encoded)
        let sut = AVFoundationDecoder()

        // When
        let mapped = try sut.picture(
            of: MediaFile(path: file),
            atFrame: 0,
            reading: .working(colorSpace: nil, targetPeak: 203)
        )
        let unmapped = try sut.picture(of: MediaFile(path: file), atFrame: 0, reading: .tagged)

        // Then
        let light = ToneMapping(sourcePeak: 1000, targetPeak: 203).mapped(RGB(red: 1000, green: 1000, blue: 1000))
        let expected = ColorConversion(space: .rec2100PQ).working(displayLight: light).red
        let unmappedExpected = ColorConversion(space: .rec2100PQ)
            .working(displayLight: RGB(red: 1000, green: 1000, blue: 1000)).red
        let value = workingValue(in: mapped, x: 32, y: 32)
        let unmappedValue = workingValue(in: unmapped, x: 32, y: 32)
        #expect(value.prefix(3).allSatisfy { abs($0 - expected) <= 0.01 }, "\(value) \(expected)")
        #expect(unmappedValue.prefix(3).allSatisfy { abs($0 - unmappedExpected) <= 0.02 }, "\(unmappedValue)")
    }

    @Test("a `colorSpace` read replaces the tags: an sRGB-tagged 0.5 read as rec709 is 0.4735")
    func readsInWrittenColorSpace() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("grey.mov")
        try await ColorMovieWriter(size: size, colorSpace: .srgb).write(to: file, red: 0.5, green: 0.5, blue: 0.5)
        let sut = AVFoundationDecoder()

        // When
        let picture = try sut.picture(
            of: MediaFile(path: file),
            atFrame: 0,
            reading: .working(colorSpace: .rec709, targetPeak: nil)
        )

        // Then
        let value = workingValue(in: picture, x: 32, y: 32)
        #expect(value.prefix(3).allSatisfy { abs($0 - 0.4735) <= 0.01 }, "\(value)")
    }

    @Test("an analysis read is 8-bit sRGB clipped to 0 to 1, an HDR picture tone mapped to 203 cd/m²")
    func readsAnalysisPicture() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let wide = directory.file("wide.mov")
        let bright = directory.file("bright.mov")
        let encoded = PerceptualQuantizer().encoded(displayLight: 1000)
        try await ColorMovieWriter(size: size, colorSpace: .displayP3).write(to: wide, red: 1, green: 0, blue: 0)
        try await ColorMovieWriter(size: size, colorSpace: .rec2100PQ)
            .write(to: bright, red: encoded, green: encoded, blue: encoded)
        let sut = AVFoundationDecoder()

        // When
        let widePicture = try sut.picture(of: MediaFile(path: wide), atFrame: 0, reading: .analysis(colorSpace: nil))
        let brightPicture = try sut.picture(of: MediaFile(path: bright), atFrame: 0, reading: .analysis(colorSpace: nil))

        // Then
        #expect(widePicture.depth == .eight)
        #expect(brightPicture.depth == .eight)
        let widePixel = pixel(in: widePicture, x: 32, y: 32)
        let brightPixel = pixel(in: brightPicture, x: 32, y: 32)
        #expect(zip(widePixel, [255, 0, 0, 255]).allSatisfy { abs($0 - $1) <= 1 }, "\(widePixel)")
        #expect(zip(brightPixel, [255, 255, 255, 255]).allSatisfy { abs($0 - $1) <= 3 }, "\(brightPixel)")
    }

    @Test("a still with a LUT-based profile stops at a read with no `colorSpace`, and its probe names no space")
    func refusesLUTProfile() throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("print.jpg")
        try ColorImageWriter(size: size, colorSpace: try #require(CGColorSpace(name: CGColorSpace.genericCMYK)))
            .write(to: file, codeValues: [0, 255, 255, 0])
        let sut = AVFoundationDecoder()

        // When
        let probed = try #require(try sut.probedMedia(of: file))

        // Then
        #expect(probed.colorSpace?.name == nil)
        let error = #expect(throws: DecoderError.self) {
            try sut.picture(of: MediaFile(path: file), atFrame: 0, reading: .tagged)
        }
        guard case let .unconvertibleColor(refused, _)? = error else {
            Issue.record("\(String(describing: error))")
            return
        }
        #expect(refused == file)
    }

    @Test("a probe reports the colour facts a video and a still are tagged with")
    func probesColorFacts() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let pq = directory.file("pq.mov")
        let srgb = directory.file("srgb.mov")
        let still = directory.file("p3.png")
        try await ColorMovieWriter(size: size, colorSpace: .rec2100PQ).write(to: pq, red: 0.5, green: 0.5, blue: 0.5)
        try await ColorMovieWriter(size: size, colorSpace: .srgb).write(to: srgb, red: 0.5, green: 0.5, blue: 0.5)
        try ColorImageWriter(size: size, colorSpace: try #require(CGColorSpace(name: CGColorSpace.displayP3)))
            .write(to: still, codeValues: [255, 0, 0])
        let sut = AVFoundationDecoder()

        // When
        let pqFacts = try #require(try sut.probedMedia(of: pq)).colorSpace
        let srgbFacts = try #require(try sut.probedMedia(of: srgb)).colorSpace
        let stillFacts = try #require(try sut.probedMedia(of: still)).colorSpace

        // Then
        #expect(pqFacts == ProbedColorSpace(
            name: .rec2100PQ,
            primaries: 9,
            transfer: 16,
            matrix: 9,
            bitDepth: 10,
            isHighDynamicRange: true
        ))
        #expect(srgbFacts == ProbedColorSpace(
            name: .srgb,
            primaries: 1,
            transfer: 13,
            matrix: 1,
            bitDepth: 8,
            isHighDynamicRange: false
        ))
        #expect(stillFacts == ProbedColorSpace(
            name: .displayP3,
            primaries: 12,
            transfer: 13,
            matrix: nil,
            bitDepth: 8,
            isHighDynamicRange: false
        ))
    }

    // MARK: - Private
    // An RGB space of BT.709 primaries and a D65 white whose curve is the gamma 2.4 of BT.1886.
    private static func rec709Profile() -> CGColorSpace? {
        // The columns of the BT.709 to XYZ matrix, adapted to D50 by Bradford, as an ICC profile holds its colorants.
        let matrix: [CGFloat] = [
            0.4360, 0.2225, 0.0139,
            0.3851, 0.7169, 0.0971,
            0.1431, 0.0606, 0.7139
        ]
        let white: [CGFloat] = [0.9642, 1, 0.8249]
        let black: [CGFloat] = [0, 0, 0]
        let gamma: [CGFloat] = [2.4, 2.4, 2.4]

        return CGColorSpace(calibratedRGBWhitePoint: white, blackPoint: black, gamma: gamma, matrix: matrix)
    }

    // The working value of a half float picture's pixel, RGBA.
    private func workingValue(
        in picture: Bitmap,
        x: Int,
        y: Int
    ) -> [Double] {
        guard picture.depth == .halfFloat else { return [] }

        let start = y * picture.bytesPerRow + x * 8
        return picture.pixels[start..<start + 8].withUnsafeBytes { bytes in
            bytes.bindMemory(to: Float16.self).map { Double($0) }
        }
    }

    private func pixel(
        in picture: Bitmap,
        x: Int,
        y: Int
    ) -> [Int] {
        let start = y * picture.bytesPerRow + x * 4

        return picture.pixels[start..<start + 4].map(Int.init)
    }
}

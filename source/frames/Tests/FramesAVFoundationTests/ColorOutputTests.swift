//
//  ColorOutputTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/20/26.
//

import AVFoundation
import CoreGraphics
import Foundation
import Frames
@testable import FramesAVFoundation
import FramesTestMedia
import ImageIO
import Testing

// What the encoder writes in a colour space (FRAMES-26 Output): images and videos whose encoded values, read back by
// ImageIO and AVFoundation and taken to working values by the space's formulas, are the working values written, tagged
// with the space; analysis pictures; and the HDR targets it refuses. Serialized, since the hardware encoders are shared
// by every test, and so that the tests running at once read far fewer files with AVFoundation than the 64 at once at
// which its reads stop finishing (FRAMES-21 Notes).
@Suite("Color Output Tests", .serialized, .ownThread)
struct ColorOutputTests {
    // MARK: - Property
    private static let size = Size(width: 64, height: 48)
    // Working values inside every space's gamut and below its peak, one to a band of the picture.
    private static let colors = [
        RGB(red: 0.5, green: 0.5, blue: 0.5),
        RGB(red: 0.6, green: 0.3, blue: 0.2),
        RGB(red: 0.2, green: 0.4, blue: 0.8)
    ]
    // The middle of each band, away from the edges where a video's chroma is shared.
    private static let bandCentres = [10, 32, 53]

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a 16-bit PNG in each colour space holds the working values written, encoded and tagged with the space",
        arguments: ColorSpace.allCases
    )
    func roundTripsPNG(space: ColorSpace) throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("image.png")
        let output = ColorConversion(space: space)

        // When
        try AVFoundationEncoder().writeImage(
            bands(Self.colors),
            for: .png(path: path, size: Self.size, depth: .sixteen, output: output)
        )

        // Then
        let image = try image(at: path)
        #expect(ColorSpace(imageSpace: try #require(image.colorSpace)) == space)
        for (x, color) in zip(Self.bandCentres, Self.colors) {
            let working = output.working(try encoded(of: image, x: x, y: 24))
            #expect(distance(working, color) < 0.001)
        }
    }

    @Test(
        "an SDR PNG reads back by its profile to its working values, rec709 and rec2020 by BT.1886",
        arguments: [ColorSpace.srgb, .displayP3, .rec709, .rec2020]
    )
    func readsPNGByProfile(space: ColorSpace) throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("image.png")

        // When
        try AVFoundationEncoder().writeImage(
            bands(Self.colors),
            for: .png(path: path, size: Self.size, depth: .sixteen, output: ColorConversion(space: space))
        )

        // Then
        let working = try extendedSRGB(of: image(at: path))
        for (x, color) in zip(Self.bandCentres, Self.colors) {
            #expect(distance(working[24 * 64 + x], color) < 0.002)
        }
    }

    @Test(
        "a PNG takes an sRGB chunk in srgb and an ICC profile of its space in every other, at its target's depth",
        arguments: ColorSpace.allCases,
        [BitDepth.eight, .sixteen]
    )
    func tagsPNG(
        space: ColorSpace,
        depth: BitDepth
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("image.png")

        // When
        try AVFoundationEncoder().writeImage(
            bands(Self.colors),
            for: .png(path: path, size: Self.size, depth: depth, output: ColorConversion(space: space))
        )

        // Then
        let chunks = try pngChunks(at: path).map(\.0)
        #expect(chunks.contains("sRGB") == (space == .srgb))
        #expect(chunks.contains("iCCP") == (space != .srgb))
        let header = try #require(try pngChunks(at: path).first { $0.0 == "IHDR" }?.1)
        #expect(Int(header[8]) == depth.bitsPerComponent)
    }

    @Test(
        "a HEIC holds 10 bits in an HDR colour space and 8 in an SDR one, tagged with the space",
        arguments: [(ColorSpace.rec2100PQ, 10), (.rec2100HLG, 10), (.displayP3, 8), (.rec709, 8)]
    )
    func writesHEIC(
        space: ColorSpace,
        bits: Int
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("image.heic")
        let output = ColorConversion(space: space)

        // When
        try AVFoundationEncoder().writeImage(
            bands(Self.colors),
            for: .heic(path: path, size: Self.size, quality: .high, output: output)
        )

        // Then
        let source = try #require(CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyDepth] as? Int == bits)
        let image = try image(at: path)
        #expect(ColorSpace(imageSpace: try #require(image.colorSpace)) == space)
        let working = output.working(try encoded(of: image, x: 32, y: 24))
        #expect(distance(working, Self.colors[1]) < 0.02)
    }

    @Test(
        "a delivery reads back to its working values, H.264 in SDR and HEVC Main 10 in HDR, with the space's tags",
        arguments: [ColorSpace.srgb, .displayP3, .rec709, .rec2100PQ, .rec2100HLG]
    )
    func roundTripsDelivery(space: ColorSpace) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("delivery.mp4")
        let output = ColorConversion(space: space)
        let sut = AVFoundationEncoder()
        try sut.check(EncodeTarget.delivery(path: path, output: output))

        // When
        let writer = try sut.videoWriter(for: .delivery(path: path, output: output), size: Self.size, fps: 30, sound: nil)
        for _ in 0..<4 {
            try writer.append(.bitmap(bands(Self.colors)))
        }
        try writer.finish()

        // Then
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let format = try #require(try await track.load(.formatDescriptions).first)
        let extensions = CMFormatDescriptionGetExtensions(format) as? [String: Any] ?? [:]
        let isHighDynamicRange = space.isHighDynamicRange
        #expect(CMFormatDescriptionGetMediaSubType(format) == (isHighDynamicRange ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264))
        let tags = space.videoColorProperties
        #expect(extensions[kCVImageBufferColorPrimariesKey as String] as? String == tags[AVVideoColorPrimariesKey])
        #expect(extensions[kCVImageBufferTransferFunctionKey as String] as? String == tags[AVVideoTransferFunctionKey])
        #expect(extensions[kCVImageBufferYCbCrMatrixKey as String] as? String == tags[AVVideoYCbCrMatrixKey])
        if isHighDynamicRange {
            #expect(extensions[kCMFormatDescriptionExtension_BitsPerComponent as String] as? Int == 10)
        }
        let encoded = try firstFrame(of: track, in: asset)
        for (x, color) in zip(Self.bandCentres, Self.colors) {
            #expect(distance(output.working(encoded[24 * 64 + x]), color) < 0.03)
        }
    }

    @Test(
        "an analysis picture of an HDR frame is its output tone mapped from the peak to 203, an 8-bit sRGB PNG",
        arguments: [(ColorSpace.rec2100PQ, 1000.0, 0.898), (.rec2100PQ, 400, 0.956), (.rec2100PQ, 4000, 0.815), (.rec2100HLG, 1000, 0.898)]
    )
    func writesAnalysisPicture(
        space: ColorSpace,
        peak: Double,
        white: Double
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("analysis.png")
        let output = ColorConversion(space: space, peak: peak)
        let atPeak = output.working(displayLight: RGB(red: peak, green: peak, blue: peak))

        // When
        try AVFoundationEncoder().writeAnalysisPicture(
            of: bands([RGB(red: 1, green: 1, blue: 1), atPeak, RGB(red: 1, green: 1, blue: 1)]),
            in: output,
            to: path
        )

        // Then
        let chunks = try pngChunks(at: path)
        #expect(chunks.map(\.0).contains("sRGB"))
        #expect(chunks.first { $0.0 == "IHDR" }?.1[8] == 8)
        let image = try image(at: path)
        let referenceWhite = try encoded(of: image, x: Self.bandCentres[0], y: 24)
        #expect(abs(referenceWhite.red - white) <= 1.0 / 255 + 0.001)
        let atPeakRead = try encoded(of: image, x: Self.bandCentres[1], y: 24)
        #expect(distance(atPeakRead, RGB(red: 1, green: 1, blue: 1)) <= 1.0 / 255)
    }

    @Test("an analysis picture of an SDR frame is its working values clipped to 0 to 1")
    func clipsAnalysisPicture() throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("analysis.png")
        let frame = bands([RGB(red: 1.25, green: -0.25, blue: 0.5), RGB(red: 0, green: 0, blue: 0), RGB(red: 1, green: 1, blue: 1)])

        // When
        try AVFoundationEncoder().writeAnalysisPicture(of: frame, in: ColorConversion(space: .displayP3), to: path)

        // Then
        let pixel = try encoded(of: image(at: path), x: Self.bandCentres[0], y: 24)
        #expect(pixel.red == 1)
        #expect(pixel.green == 0)
        #expect(abs(pixel.blue - 0.5) <= 1.0 / 255)
    }

    @Test("H.264 and JPEG in an HDR colour space are refused by the check", arguments: [ColorSpace.rec2100PQ, .rec2100HLG])
    func refusesHighDynamicRange(space: ColorSpace) {
        // Given
        let sut = AVFoundationEncoder()
        let output = ColorConversion(space: space)

        // When, Then
        #expect(throws: EncoderError.highDynamicRange(file: "a.mp4", codec: "H.264", colorSpace: space)) {
            try sut.check(EncodeTarget.compressed(path: "a.mp4", codec: .h264, quality: .medium, size: Self.size, output: output))
        }
        #expect(throws: EncoderError.highDynamicRange(file: "a.jpg", codec: "JPEG", colorSpace: space)) {
            try sut.check(ImageTarget.jpeg(path: "a.jpg", size: Self.size, quality: .medium, output: output))
        }
        #expect(throws: Never.self) {
            try sut.check(EncodeTarget.compressed(path: "a.mp4", codec: .hevc, quality: .medium, size: Self.size, output: output))
            try sut.check(ImageTarget.heic(path: "a.heic", size: Self.size, quality: .medium, output: output))
        }
    }

    @Test("a half float bitmap with values above 1 and below 0 makes an extended sRGB image whose pixels read back")
    func readsHalfFloatImage() throws {
        // Given
        let colors = [RGB(red: 1.5, green: -0.25, blue: 0.5), RGB(red: -0.5, green: 2, blue: 1)]
        let components: [Float16] = colors.flatMap { [Float16($0.red), Float16($0.green), Float16($0.blue), 1] }
        let bitmap = Bitmap(
            width: 2,
            height: 1,
            depth: .halfFloat,
            bytesPerRow: 16,
            pixels: components.withUnsafeBytes { Data($0) }
        )

        // When
        let image = try #require(bitmap.image())

        // Then
        let read = try extendedSRGB(of: image)
        for (pixel, color) in zip(read, colors) {
            #expect(distance(pixel, color) < 0.001)
        }
    }

    // MARK: - Private
    // An opaque half float picture of working values, one colour to each of three bands from left to right.
    private func bands(_ colors: [RGB]) -> Bitmap {
        let width = Int(Self.size.width)
        let height = Int(Self.size.height)
        var components: [Float16] = []
        for _ in 0..<height {
            for x in 0..<width {
                let color = colors[min(x * colors.count / width, colors.count - 1)]
                components += [Float16(color.red), Float16(color.green), Float16(color.blue), 1]
            }
        }

        return Bitmap(
            width: width,
            height: height,
            depth: .halfFloat,
            bytesPerRow: width * 8,
            pixels: components.withUnsafeBytes { Data($0) }
        )
    }

    private func distance(
        _ value: RGB,
        _ other: RGB
    ) -> Double {
        max(abs(value.red - other.red), abs(value.green - other.green), abs(value.blue - other.blue))
    }

    private func image(at path: String) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil))

        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    // A pixel's colour as the file stores it, with no colour conversion: an integer channel from 0 to 1, a half float one
    // as it is. ImageIO reads a 10-bit HEIC as 32-bit pixels of three 10-bit channels below 2 unused bits.
    private func encoded(
        of image: CGImage,
        x: Int,
        y: Int
    ) throws -> RGB {
        let data = try #require(image.dataProvider?.data as Data?)
        let offset = y * image.bytesPerRow + x * image.bitsPerPixel / 8
        if image.bitsPerComponent == 10 {
            #expect(image.bitsPerPixel == 32)
            let bytes = (0..<4).map { UInt32(data[offset + $0]) }
            let pixel = image.bitmapInfo.contains(.byteOrder32Little)
                ? bytes[0] | bytes[1] << 8 | bytes[2] << 16 | bytes[3] << 24
                : bytes[0] << 24 | bytes[1] << 16 | bytes[2] << 8 | bytes[3]
            let channels = [20, 10, 0].map { Double(pixel >> UInt32($0) & 0x3FF) / 1023 }

            return RGB(red: channels[0], green: channels[1], blue: channels[2])
        }

        let bytesPerComponent = image.bitsPerComponent / 8
        let isLittle = image.bitmapInfo.contains(.byteOrder16Little)
        let isFloat = image.bitmapInfo.contains(.floatComponents)
        let channels = (0..<3).map { channel -> Double in
            let start = offset + channel * bytesPerComponent
            guard bytesPerComponent == 2 else { return Double(data[start]) / 255 }

            let value = isLittle
                ? UInt16(data[start]) | UInt16(data[start + 1]) << 8
                : UInt16(data[start]) << 8 | UInt16(data[start + 1])
            guard !isFloat else { return Double(Float16(bitPattern: value)) }

            return Double(value) / 65_535
        }

        return RGB(red: channels[0], green: channels[1], blue: channels[2])
    }

    // Every pixel drawn by Core Graphics into extended sRGB, which are working values, rows top first.
    private func extendedSRGB(of image: CGImage) throws -> [RGB] {
        let context = try #require(CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 32,
            bytesPerRow: image.width * 16,
            space: CGColorSpace(name: CGColorSpace.extendedSRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.floatComponents.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let floats = try #require(context.data).assumingMemoryBound(to: Float.self)

        return (0..<image.width * image.height).map { pixel in
            RGB(red: Double(floats[pixel * 4]), green: Double(floats[pixel * 4 + 1]), blue: Double(floats[pixel * 4 + 2]))
        }
    }

    // The first frame of a video as its R'G'B' values, read with no colour conversion.
    private func firstFrame(
        of track: AVAssetTrack,
        in asset: AVAsset
    ) throws -> [RGB] {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_64RGBAHalf]
        )
        reader.add(output)
        #expect(reader.startReading())
        let sample = try #require(output.copyNextSampleBuffer())
        let buffer = try #require(CMSampleBufferGetImageBuffer(sample))
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let base = try #require(CVPixelBufferGetBaseAddress(buffer))
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let width = CVPixelBufferGetWidth(buffer)
        reader.cancelReading()

        return (0..<CVPixelBufferGetHeight(buffer) * width).map { pixel in
            let row = (base + (pixel / width) * bytesPerRow).assumingMemoryBound(to: Float16.self)
            let x = pixel % width

            return RGB(red: Double(row[x * 4]), green: Double(row[x * 4 + 1]), blue: Double(row[x * 4 + 2]))
        }
    }

    private func pngChunks(at path: String) throws -> [(String, [UInt8])] {
        let data = [UInt8](try Data(contentsOf: URL(fileURLWithPath: path)))
        var chunks: [(String, [UInt8])] = []
        var offset = 8
        while offset + 8 <= data.count {
            let length = data[offset..<offset + 4].reduce(0) { $0 << 8 | Int($1) }
            let type = String(decoding: data[offset + 4..<offset + 8], as: UTF8.self)
            chunks.append((type, Array(data[offset + 8..<offset + 8 + length])))
            offset += 12 + length
        }

        return chunks
    }
}

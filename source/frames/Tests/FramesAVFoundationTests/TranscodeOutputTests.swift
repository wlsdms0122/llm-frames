//
//  TranscodeOutputTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/17/26.
//

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Frames
import FramesAVFoundation
import FramesTestMedia
import Testing

// Transcodes real files through the `avfoundation` decoder and encoder. Serialized, since the hardware encoders are
// shared by every test, and so that the tests running at once read far fewer files with AVFoundation than the 64 at
// once at which its reads stop finishing (FRAMES-21 Notes).
@Suite("Transcode Output Tests", .serialized, .ownThread, .timeLimit(.minutes(5)))
struct TranscodeOutputTests {
    // MARK: - Property
    // These tests read the file a writer leaves and none of them is about how long the writer takes, so the encoder
    // waits on its writers without a deadline, and the suite's time limit ends a writer that never finishes.
    private static let deadline = Double.infinity
    private static let frameTimes = (0..<8).map { Double($0) / 30 }

    private let size = Size(width: 64, height: 48)

    // MARK: - Initializer
    // MARK: - Test
    @Test("an image transcodes to each image extension at its own size", arguments: [
        ("jpg", TranscodeFormat.jpeg),
        ("heic", TranscodeFormat.heic),
        ("png", TranscodeFormat.png)
    ])
    func transcodesImage(
        outputExtension: String,
        format: TranscodeFormat
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = directory.file("in.png")
        try ImageWriter(size: size).write(to: input) { canvas in
            canvas.fill(red: 200, green: 40, blue: 40)
        }
        let output = directory.file("out.\(outputExtension)")
        let (sut, decoder) = transcoder()

        // When
        let result = try sut.transcode(TranscodeRequest(input: input, output: output))
        let probed = try decoder.probedMedia(of: output)

        // Then
        #expect(result.format == format)
        #expect(result.byteCount == (try FileManager.default.attributesOfItem(atPath: output)[.size] as? Int))
        #expect(probed?.kind == .image)
        #expect(probed?.size == size)
    }

    @Test("a page is drawn at --scale to a 16-bit PNG, unpainted area transparent, or to a JPEG over white", arguments: [
        ("png", 16, [0.0, 0, 0, 0]),
        ("jpg", 8, [1.0, 1, 1, 1])
    ])
    func transcodesPage(
        outputExtension: String,
        bitsPerComponent: Int,
        unpainted: [Double]
    ) throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = directory.file("logo.pdf")
        try DocumentWriter(sizes: [Size(width: 20, height: 10)]).write(to: input) { _, canvas in
            canvas.fill(Rectangle(x: 0, y: 0, width: 10, height: 10), red: 255, green: 0, blue: 0)
        }
        let output = directory.file("logo.\(outputExtension)")
        let (sut, decoder) = transcoder()

        // When
        _ = try sut.transcode(TranscodeRequest(input: input, output: output, scale: 2.5))

        // Then
        let source = try #require(CGImageSourceCreateWithURL(URL(fileURLWithPath: output) as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 50 && image.height == 25)
        #expect(image.bitsPerComponent == bitsPerComponent)
        let picture = try decoder.picture(of: MediaFile(path: output), atFrame: 0).bitmap
        let painted = pixel(of: picture, x: 10, y: 12)
        let empty = pixel(of: picture, x: 40, y: 12)
        #expect(zip(painted, [1.0, 0, 0, 1]).allSatisfy { abs($0 - $1) < 0.01 }, "\(painted)")
        #expect(zip(empty, unpainted).allSatisfy { abs($0 - $1) < 0.01 }, "\(empty)")
    }

    @Test("a sound transcodes to an .m4a of the same length")
    func transcodesSound() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = directory.file("in.wav")
        try await SoundWriter(end: 1, levels: [0.2, 0.2]).write(to: input)
        let output = directory.file("out.m4a")
        let (sut, decoder) = transcoder()

        // When
        let result = try sut.transcode(TranscodeRequest(input: input, output: output))

        // Then
        #expect(result.format == .aac)
        #expect(result.isSmaller)
        let probed = try #require(try decoder.probedMedia(of: output))
        #expect(probed.kind == .audio)
        #expect(abs(probed.duration - 1) < 0.05)
    }

    @Test("a video transcodes to each video extension with its frames and sound", arguments: [
        ("mp4", VideoCodec.h264),
        ("mov", VideoCodec.h264),
        ("m4v", VideoCodec.h264),
        ("mp4", VideoCodec.hevc)
    ])
    func transcodesVideo(
        outputExtension: String,
        codec: VideoCodec
    ) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try await video(in: directory)
        let output = directory.file("out.\(outputExtension)")
        let (sut, decoder) = transcoder()

        // When
        let result = try sut.transcode(TranscodeRequest(input: input, output: output, codec: codec))

        // Then
        #expect(result.format == .video(codec: codec, hasSound: true))
        let probed = try #require(try decoder.probedMedia(of: output))
        #expect(probed.kind == .video)
        #expect(probed.size == size)
        #expect(probed.frames.count == Self.frameTimes.count)
        #expect(probed.hasSound)
        #expect(abs(probed.duration - 8.0 / 30) < 1.0 / 30)
    }

    @Test("a video transcodes to an .m4a of its sound alone")
    func transcodesSoundOfVideo() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try await video(in: directory)
        let output = directory.file("out.m4a")
        let (sut, decoder) = transcoder()

        // When
        let result = try sut.transcode(TranscodeRequest(input: input, output: output))

        // Then
        #expect(result.format == .aac)
        let probed = try #require(try decoder.probedMedia(of: output))
        #expect(probed.kind == .audio)
        #expect(abs(probed.duration - 8.0 / 30) < 0.05)
    }

    @Test("a turned video is written with its turn applied to the pixels")
    func appliesVideoTurn() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = directory.file("turned.mov")
        let quarterTurn = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: size.height, ty: 0)
        let writer = MovieWriter(
            size: Size(width: size.height, height: size.width),
            frameTimes: Self.frameTimes,
            end: 8.0 / 30,
            transform: quarterTurn
        )
        try await writer.write(to: input) { canvas, _ in
            canvas.fill(red: 0, green: 0, blue: 255)
            canvas.fill(Rectangle(x: 0, y: 0, width: 32, height: 48), red: 255, green: 0, blue: 0)
        }
        let output = directory.file("out.mp4")
        let (sut, decoder) = transcoder()

        // When
        _ = try sut.transcode(TranscodeRequest(input: input, output: output))

        // Then
        let asset = AVURLAsset(url: URL(fileURLWithPath: output))
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        #expect(try await track.load(.preferredTransform) == .identity)
        #expect(try await track.load(.naturalSize) == CGSize(width: 64, height: 48))
        let picture = try decoder.picture(of: MediaFile(path: output, frameTimes: Self.frameTimes), atFrame: 0).bitmap
        let left = pixel(of: picture, x: 8, y: 24)
        let right = pixel(of: picture, x: 56, y: 24)
        #expect(left[0] > 0.8 && left[2] < 0.2)
        #expect(right[0] < 0.2 && right[2] > 0.8)
    }

    @Test("an image's orientation is applied to its pixels, and its location and other metadata are not copied")
    func dropsImageMetadata() throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = directory.file("photo.jpg")
        try photo(to: input)
        let output = directory.file("out.jpg")
        let (sut, _) = transcoder()

        // When
        _ = try sut.transcode(TranscodeRequest(input: input, output: output))

        // Then
        let source = try #require(CGImageSourceCreateWithURL(URL(fileURLWithPath: output) as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 48)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 64)
        #expect((properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        #expect(exif[kCGImagePropertyExifUserComment] == nil)
    }

    @Test("--max caps a video's longer side to an even size")
    func capsVideo() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try await video(in: directory)
        let output = directory.file("out.mp4")
        let (sut, decoder) = transcoder()

        // When
        _ = try sut.transcode(TranscodeRequest(input: input, output: output, maximumSide: 41))

        // Then
        #expect(try decoder.probedMedia(of: output)?.size == Size(width: 40, height: 30))
    }

    @Test("an existing output is replaced by the transcoded file")
    func replacesExistingOutput() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try await video(in: directory)
        let output = directory.file("out.mp4")
        try Data("not a movie".utf8).write(to: URL(fileURLWithPath: output))
        let (sut, decoder) = transcoder()

        // When
        _ = try sut.transcode(TranscodeRequest(input: input, output: output))

        // Then
        #expect(try decoder.probedMedia(of: output)?.kind == .video)
    }

    @Test("a sound the encoder cannot write stops in its check and leaves an existing output in place")
    func keepsOutputOfUnwritableSound() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = directory.file("in.wav")
        try await SoundWriter(end: 0.5, sampleRate: 9_000).write(to: input)
        let output = directory.file("out.m4a")
        let existing = Data("not a sound".utf8)
        try existing.write(to: URL(fileURLWithPath: output))
        let (sut, _) = transcoder()

        // When
        #expect(throws: EncoderError.unwritable(file: output, reason: "AAC at 9000 Hz is not written")) {
            try sut.transcode(TranscodeRequest(input: input, output: output))
        }

        // Then
        #expect(try Data(contentsOf: URL(fileURLWithPath: output)) == existing)
    }

    // MARK: - Private
    private func transcoder() -> (Transcoder, AVFoundationDecoder) {
        let decoder = AVFoundationDecoder()
        let encoder = AVFoundationEncoder(deadline: Self.deadline)

        return (Transcoder(decoder: decoder, facts: decoder, encoder: encoder), decoder)
    }

    // Eight frames at 30 a second with a tone, red on the left half and blue on the right.
    private func video(in directory: TemporaryDirectory) async throws -> String {
        let path = directory.file("in.mov")
        let writer = MovieWriter(size: size, frameTimes: Self.frameTimes, end: 8.0 / 30, sound: true)
        try await writer.write(to: path) { canvas, _ in
            canvas.fill(red: 0, green: 0, blue: 255)
            canvas.fill(Rectangle(x: 0, y: 0, width: 32, height: 48), red: 255, green: 0, blue: 0)
        }

        return path
    }

    // A 64 by 48 JPEG stored turned, displayed 48 by 64 by its orientation, with a location and a comment.
    private func photo(to path: String) throws {
        let context = try #require(CGContext(
            data: nil,
            width: 64,
            height: 48,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: 0.2, green: 0.6, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: path) as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ))
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 37.5,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 127.0,
                kCGImagePropertyGPSLongitudeRef: "E"
            ],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "secret"]
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))

        let written = try #require(CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil))
        let read = CGImageSourceCopyPropertiesAtIndex(written, 0, nil) as? [CFString: Any] ?? [:]
        #expect(read[kCGImagePropertyGPSDictionary] != nil)
    }

    // The RGBA of a pixel of a decoded picture, from 0 to 1.
    private func pixel(
        of picture: Bitmap,
        x: Int,
        y: Int
    ) -> [Double] {
        picture.pixels.withUnsafeBytes { bytes in
            let row = bytes.baseAddress! + y * picture.bytesPerRow

            return (0..<4).map { component in
                switch picture.depth {
                case .sixteen:
                    Double(row.assumingMemoryBound(to: UInt16.self)[x * 4 + component]) / 65_535

                case .eight:
                    Double(row.assumingMemoryBound(to: UInt8.self)[x * 4 + component]) / 255

                case .halfFloat:
                    Double(row.assumingMemoryBound(to: Float16.self)[x * 4 + component])
                }
            }
        }
    }
}

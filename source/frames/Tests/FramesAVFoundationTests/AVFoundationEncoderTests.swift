//
//  AVFoundationEncoderTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/17/26.
//

import AVFoundation
import Foundation
import ImageIO
import Frames
import FramesAVFoundation
import FramesTestMedia
import Testing

// Serialized, since the hardware encoders and AVAssetReader are shared by every test.
@Suite("AVFoundationEncoder Tests", .serialized)
struct AVFoundationEncoderTests {
    // MARK: - Property
    private static let deadline = 20.0

    // Half transparent red on the left half, transparent in the third quarter, opaque grey in the last, premultiplied.
    private static let halfRed: [UInt16] = [32_768, 0, 0, 32_768]
    private static let clear: [UInt16] = [0, 0, 0, 0]
    private static let grey: [UInt16] = [32_768, 32_768, 32_768, 65_535]

    private let width = 64
    private let height = 48
    private let frameCount = 16

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a master is ProRes 422 HQ, or ProRes 4444 with alpha, tagged sRGB, with 24-bit PCM at 48 kHz in stereo",
        arguments: [false, true]
    )
    func writesMaster(alpha: Bool) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("master.mov")
        let sut = AVFoundationEncoder(deadline: Self.deadline)

        // When
        try write(.master(path: path, alpha: alpha), fps: 30, sound: tone(seconds: 16.0 / 30), with: sut)

        // Then
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let format = try #require(try await video.load(.formatDescriptions).first)
        let codec = alpha ? kCMVideoCodecType_AppleProRes4444 : kCMVideoCodecType_AppleProRes422HQ
        #expect(CMFormatDescriptionGetMediaSubType(format) == codec)
        expectColourTags(of: format)
        #expect(try await presentationTimes(of: video, in: asset) == (0..<frameCount).map {
            CMTime(value: CMTimeValue($0 * 1000), timescale: 30_000)
        })
        try await expectDuration(of: asset, seconds: 16.0 / 30, fps: 30)

        let audio = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let sound = try #require(try await audio.load(.formatDescriptions).first.flatMap {
            CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee
        })
        #expect(sound.mFormatID == kAudioFormatLinearPCM)
        #expect(sound.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0)
        #expect(sound.mFormatFlags & kAudioFormatFlagIsFloat == 0)
        #expect(sound.mBitsPerChannel == 24)
        #expect(sound.mSampleRate == 48_000)
        #expect(sound.mChannelsPerFrame == 2)
    }

    @Test("a ProRes 4444 master keeps alpha: a transparent pixel and a half transparent one decode as written")
    func keepsAlphaInProRes4444() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("alpha.mov")
        let sut = AVFoundationEncoder(deadline: Self.deadline)
        try write(.master(path: path, alpha: true), fps: 30, sound: nil, with: sut)
        let decoder = AVFoundationDecoder()

        // When
        let media = MediaFile(path: path, size: size, frameTimes: thirtieths)
        let picture = try decoder.picture(of: media, atFrame: 3)

        // Then
        let tolerance = 2.0 / 255
        #expect(zip(pixel(of: picture, x: 16, y: 24), [0.5, 0, 0, 0.5]).allSatisfy { abs($0 - $1) <= tolerance })
        #expect(zip(pixel(of: picture, x: 40, y: 24), [0, 0, 0, 0]).allSatisfy { abs($0 - $1) <= tolerance })
        #expect(zip(pixel(of: picture, x: 56, y: 24), [0.5, 0.5, 0.5, 1]).allSatisfy { abs($0 - $1) <= tolerance })
    }

    @Test("a delivery is H.264 tagged sRGB with AAC near 256 kbps, and its frames are over black")
    func writesDeliveryOverBlack() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("delivery.mp4")
        let sut = AVFoundationEncoder(deadline: Self.deadline)

        // When
        try write(.delivery(path: path), fps: 30, sound: tone(seconds: 16.0 / 30), with: sut)

        // Then
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let format = try #require(try await video.load(.formatDescriptions).first)
        #expect(CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_H264)
        expectColourTags(of: format)
        #expect(try await presentationTimes(of: video, in: asset).count == frameCount)
        try await expectDuration(of: asset, seconds: 16.0 / 30, fps: 30)

        let audio = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let sound = try #require(try await audio.load(.formatDescriptions).first.flatMap {
            CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee
        })
        #expect(sound.mFormatID == kAudioFormatMPEG4AAC)
        #expect(sound.mSampleRate == 48_000)
        #expect(sound.mChannelsPerFrame == 2)
        let bitRate = Double(try await audio.load(.estimatedDataRate))
        #expect(abs(bitRate - 256_000) <= 256_000 * 0.1)

        let media = MediaFile(path: path, size: size, frameTimes: thirtieths)
        let picture = try AVFoundationDecoder().picture(of: media, atFrame: 3)
        let tolerance = 8.0 / 255
        #expect(zip(pixel(of: picture, x: 16, y: 24), [0.5, 0, 0, 1]).allSatisfy { abs($0 - $1) <= tolerance })
        #expect(zip(pixel(of: picture, x: 40, y: 24), [0, 0, 0, 1]).allSatisfy { abs($0 - $1) <= tolerance })
    }

    @Test(
        "sound and frames longer than the writer interleaves at once all go in, in a master and in a delivery",
        arguments: ["master.mov", "delivery.mp4"]
    )
    func writesLongSound(name: String) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file(name)
        let target = name.hasSuffix(".mov") ? EncodeTarget.master(path: path, alpha: false) : .delivery(path: path)
        let sut = AVFoundationEncoder(deadline: Self.deadline)

        // When
        try write(target, fps: 10, sound: tone(seconds: 3), frameCount: 30, with: sut)

        // Then
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        try await expectDuration(of: asset, seconds: 3, fps: 10)
        let audio = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let soundLength = CMTimeGetSeconds(try await audio.load(.timeRange).duration)
        #expect(abs(soundLength - 3) < 0.1)
    }

    @Test("frame k of a video at an NTSC rate is presented at exactly k × 1001 / 30000", arguments: [
        29.97,
        30_000.0 / 1001
    ])
    func timesNTSCFrames(fps: Double) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("ntsc.mov")
        let sut = AVFoundationEncoder(deadline: Self.deadline)

        // When
        try write(.master(path: path, alpha: false), fps: fps, sound: nil, with: sut)

        // Then
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
        #expect(try await presentationTimes(of: video, in: asset) == (0..<frameCount).map {
            CMTime(value: CMTimeValue($0 * 1001), timescale: 30_000)
        })
        try await expectDuration(of: asset, seconds: Double(frameCount) * 1001 / 30_000, fps: fps)
    }

    @Test("a video writer replaces a file already at its path")
    func replacesExistingFile() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("master.mov")
        try Data("not a movie".utf8).write(to: URL(fileURLWithPath: path))
        let sut = AVFoundationEncoder(deadline: Self.deadline)

        // When
        try write(.master(path: path, alpha: false), fps: 30, sound: nil, with: sut)

        // Then
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        #expect(try await asset.loadTracks(withMediaType: .video).count == 1)
    }

    @Test("a video writer that fails, or is let go before it finishes, leaves no file")
    func removesFailedVideo() throws {
        // Given
        let directory = try TemporaryDirectory()
        let failed = directory.file("failed.mov")
        let abandoned = directory.file("abandoned.mov")
        let sut = AVFoundationEncoder(deadline: Self.deadline)
        let writer = try sut.videoWriter(for: .master(path: failed, alpha: false), size: size, fps: 30, sound: nil)
        try writer.append(frame())

        // When
        #expect(throws: EncoderError.self) {
            try writer.append(Bitmap(width: 8, height: 8, depth: .sixteen, bytesPerRow: 64, pixels: Data(count: 512)))
        }
        do {
            let target = EncodeTarget.master(path: abandoned, alpha: false)
            let dropped = try sut.videoWriter(for: target, size: size, fps: 30, sound: nil)
            try dropped.append(frame())
        }

        // Then
        #expect(!FileManager.default.fileExists(atPath: failed))
        #expect(!FileManager.default.fileExists(atPath: abandoned))
    }

    @Test("this machine can encode every target")
    func checksTargets() throws {
        // Given
        let sut = AVFoundationEncoder()
        let targets: [EncodeTarget] = [
            .master(path: "a.mov", alpha: false),
            .master(path: "b.mov", alpha: true),
            .delivery(path: "c.mp4")
        ]

        // When
        let checked = Result { try targets.forEach(sut.check) }

        // Then
        #expect(throws: Never.self) { try checked.get() }
    }

    @Test(
        "a PNG has the bitmap's bit depth, an sRGB chunk, and its premultiplied colour as straight alpha",
        arguments: [BitDepth.sixteen, BitDepth.eight]
    )
    func writesImage(depth: BitDepth) throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("image.png")
        let sut = AVFoundationEncoder()
        let pixels = depth == .sixteen
            ? [UInt16]([32_768, 0, 0, 32_768, 0, 0, 0, 0]).withUnsafeBytes { Data($0) }
            : Data([64, 0, 0, 128, 0, 0, 0, 0])
        let bitmap = Bitmap(width: 2, height: 1, depth: depth, bytesPerRow: pixels.count, pixels: pixels)

        // When
        try sut.writeImage(bitmap, to: path)

        // Then
        let chunks = try pngChunks(at: path)
        let header = try #require(chunks.first { $0.0 == "IHDR" }?.1)
        #expect(header[8] == depth.bitsPerComponent)
        #expect(header[9] == 6)
        #expect(chunks.map(\.0).contains("sRGB"))
        let rows = try #require(try inflate(chunks.filter { $0.0 == "IDAT" }.flatMap(\.1)))
        #expect(rows.first == 0)
        let expected: [UInt8] = depth == .sixteen
            ? [255, 255, 0, 0, 0, 0, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            : [128, 0, 0, 128, 0, 0, 0, 0]
        #expect(Array(rows.dropFirst()) == expected)
    }

    @Test("a PNG that cannot be written leaves no file")
    func failsImageWithoutFile() throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("missing/image.png")
        let sut = AVFoundationEncoder()

        // When
        #expect(throws: EncoderError.self) {
            try sut.writeImage(frame(), to: path)
        }

        // Then
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    // MARK: - Private
    private var size: Size {
        Size(width: Double(width), height: Double(height))
    }

    private var thirtieths: [Double] {
        (0..<frameCount).map { Double($0) / 30 }
    }

    private func frame() -> Bitmap {
        var components: [UInt16] = []
        for _ in 0..<height {
            for x in 0..<width {
                components += x < 32 ? Self.halfRed : x < 48 ? Self.clear : Self.grey
            }
        }

        return Bitmap(
            width: width,
            height: height,
            depth: .sixteen,
            bytesPerRow: width * 8,
            pixels: components.withUnsafeBytes { Data($0) }
        )
    }

    // A 440 Hz tone at half scale in both channels.
    private func tone(seconds: Double) -> SoundBuffer {
        let count = Int(seconds * 48_000)
        let samples = (0..<count).flatMap { index in
            let level = Float(sin(2 * Double.pi * 440 * Double(index) / 48_000) * 0.5)

            return [level, level]
        }

        return SoundBuffer(sampleRate: 48_000, channels: 2, samples: samples)
    }

    private func write(
        _ target: EncodeTarget,
        fps: Double,
        sound: SoundBuffer?,
        frameCount: Int? = nil,
        with encoder: AVFoundationEncoder
    ) throws {
        let writer = try encoder.videoWriter(for: target, size: size, fps: fps, sound: sound)
        for _ in 0..<(frameCount ?? self.frameCount) {
            try writer.append(frame())
        }
        try writer.finish()
    }

    private func expectColourTags(of format: CMFormatDescription) {
        let extensions = CMFormatDescriptionGetExtensions(format) as? [String: Any] ?? [:]
        let tags = [
            kCVImageBufferColorPrimariesKey: kCVImageBufferColorPrimaries_ITU_R_709_2,
            kCVImageBufferTransferFunctionKey: kCVImageBufferTransferFunction_sRGB,
            kCVImageBufferYCbCrMatrixKey: kCVImageBufferYCbCrMatrix_ITU_R_709_2
        ]
        for (key, value) in tags {
            #expect(extensions[key as String] as? String == value as String)
        }
    }

    private func expectDuration(
        of asset: AVURLAsset,
        seconds: Double,
        fps: Double
    ) async throws {
        let duration = CMTimeGetSeconds(try await asset.load(.duration))
        #expect(abs(duration - seconds) < 1 / fps)
    }

    // The presentation time of every sample of `track`, in order.
    private func presentationTimes(
        of track: AVAssetTrack,
        in asset: AVAsset
    ) async throws -> [CMTime] {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        reader.add(output)
        #expect(reader.startReading())
        var times: [CMTime] = []
        while let sample = output.copyNextSampleBuffer() {
            if CMSampleBufferGetNumSamples(sample) > 0 {
                times.append(CMSampleBufferGetPresentationTimeStamp(sample))
            }
        }

        return times.sorted { CMTimeCompare($0, $1) < 0 }
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
                }
            }
        }
    }

    // The type and data of every chunk of a PNG, in order.
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

    // The data of a zlib stream: raw deflate between a 2 byte header and a 4 byte checksum.
    private func inflate(_ stream: [UInt8]) throws -> [UInt8]? {
        let deflated = Data(stream.dropFirst(2).dropLast(4)) as NSData

        return [UInt8](try deflated.decompressed(using: .zlib) as Data)
    }
}

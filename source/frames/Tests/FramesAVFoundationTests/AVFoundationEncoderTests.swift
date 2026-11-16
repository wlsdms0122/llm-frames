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
            .delivery(path: "c.mp4"),
            .compressed(path: "d.mp4", codec: .h264, quality: .medium, size: size),
            .compressed(path: "e.mp4", codec: .hevc, quality: .medium, size: size)
        ]
        let images: [ImageTarget] = [
            .png(path: "f.png", size: size),
            .jpeg(path: "g.jpg", size: size, quality: .medium),
            .heic(path: "h.heic", size: size, quality: .medium)
        ]

        // When
        let checked = Result {
            try targets.forEach(sut.check)
            try images.forEach(sut.check)
            try sut.check(SoundTarget(path: "i.m4a", quality: .medium))
        }

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

    @Test("a JPEG or HEIC at low quality is smaller than at high quality", arguments: ["jpg", "heic"])
    func ordersImageQuality(outputExtension: String) throws {
        // Given
        let directory = try TemporaryDirectory()
        let sut = AVFoundationEncoder()
        let bitmap = noise(width: 64, height: 48, seed: 1)
        let size = Size(width: 64, height: 48)

        // When
        let sizes = try [EncodeQuality.low, .high].map { quality in
            let path = directory.file("\(quality).\(outputExtension)")
            let target: ImageTarget = outputExtension == "jpg"
                ? .jpeg(path: path, size: size, quality: quality)
                : .heic(path: path, size: size, quality: quality)
            try sut.writeImage(bitmap, for: target)

            return try byteCount(of: path)
        }

        // Then
        #expect(sizes[0] < sizes[1])
    }

    @Test("a JPEG has its transparent parts on white, and a HEIC and a PNG keep them transparent", arguments: [
        "jpg",
        "heic",
        "png"
    ])
    func writesTransparency(outputExtension: String) throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("image.\(outputExtension)")
        let sut = AVFoundationEncoder()
        let target: ImageTarget = switch outputExtension {
        case "jpg":
            .jpeg(path: path, size: size, quality: .high)

        case "heic":
            .heic(path: path, size: size, quality: .high)

        default:
            .png(path: path, size: size)
        }

        // When
        try sut.writeImage(frame(), for: target)

        // Then
        let picture = try AVFoundationDecoder().picture(of: MediaFile(path: path), atFrame: 0)
        let tolerance = 8.0 / 255
        let (halfRed, clear): ([Double], [Double]) = outputExtension == "jpg"
            ? ([1, 0.5, 0.5, 1], [1, 1, 1, 1])
            : ([0.5, 0, 0, 0.5], [0, 0, 0, 0])
        #expect(zip(pixel(of: picture, x: 16, y: 24), halfRed).allSatisfy { abs($0 - $1) <= tolerance })
        #expect(zip(pixel(of: picture, x: 40, y: 24), clear).allSatisfy { abs($0 - $1) <= tolerance })
        #expect(zip(pixel(of: picture, x: 56, y: 24), [0.5, 0.5, 0.5, 1]).allSatisfy { abs($0 - $1) <= tolerance })
    }

    @Test("an image is scaled to its target's size and carries an sRGB profile and no other metadata", arguments: [
        "jpg",
        "heic",
        "png"
    ])
    func scalesImage(outputExtension: String) throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("image.\(outputExtension)")
        let sut = AVFoundationEncoder()
        let scaled = Size(width: 32, height: 24)
        let target: ImageTarget = switch outputExtension {
        case "jpg":
            .jpeg(path: path, size: scaled, quality: .medium)

        case "heic":
            .heic(path: path, size: scaled, quality: .medium)

        default:
            .png(path: path, size: scaled)
        }

        // When
        try sut.writeImage(frame(), for: target)

        // Then
        let source = try #require(CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 32)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 24)
        #expect(properties[kCGImagePropertyProfileName] as? String == "sRGB IEC61966-2.1")
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        #expect((properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
    }

    @Test(
        "a sound file is AAC with up to 2 channels and 48 kHz at the quality's bit rate per channel",
        arguments: [
            (1, 48_000.0, EncodeQuality.high, 1, 48_000.0),
            (2, 44_100.0, EncodeQuality.medium, 2, 44_100.0),
            (6, 48_000.0, EncodeQuality.low, 2, 48_000.0),
            (2, 96_000.0, EncodeQuality.medium, 2, 48_000.0)
        ]
    )
    func writesSound(
        channels: Int,
        sampleRate: Double,
        quality: EncodeQuality,
        writtenChannels: Int,
        writtenRate: Double
    ) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("sound.m4a")
        let sut = AVFoundationEncoder(deadline: Self.deadline)

        // When
        try sut.writeSound(
            tone(seconds: 1, sampleRate: sampleRate, channels: channels),
            for: SoundTarget(path: path, quality: quality)
        )

        // Then
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        #expect(try await asset.loadTracks(withMediaType: .video).isEmpty)
        let audio = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let sound = try #require(try await audio.load(.formatDescriptions).first.flatMap {
            CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee
        })
        #expect(sound.mFormatID == kAudioFormatMPEG4AAC)
        #expect(Int(sound.mChannelsPerFrame) == writtenChannels)
        #expect(sound.mSampleRate == writtenRate)
        let bitRate = Double(try await audio.load(.estimatedDataRate))
        let expected = Double(quality.soundBitRate * writtenChannels)
        #expect(abs(bitRate - expected) <= expected * 0.15)
        let length = CMTimeGetSeconds(try await audio.load(.timeRange).duration)
        #expect(abs(length - 1) < 0.05)
    }

    @Test(
        "a compressed video is its codec, tagged sRGB, scaled to its size, with AAC at the quality's rate",
        arguments: [VideoCodec.h264, VideoCodec.hevc]
    )
    func writesCompressedVideo(codec: VideoCodec) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("video.mov")
        let sut = AVFoundationEncoder(deadline: Self.deadline)
        let target = EncodeTarget.compressed(path: path, codec: codec, quality: .high, size: size)
        let large = Size(width: 128, height: 96)

        // When
        let writer = try sut.videoWriter(for: target, size: large, fps: 30, sound: tone(seconds: 16.0 / 30))
        for _ in 0..<frameCount {
            try writer.append(frame(width: 128, height: 96))
        }
        try writer.finish()

        // Then
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let format = try #require(try await video.load(.formatDescriptions).first)
        let codecType = codec == .hevc ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264
        #expect(CMFormatDescriptionGetMediaSubType(format) == codecType)
        expectColourTags(of: format)
        #expect(try await video.load(.naturalSize) == CGSize(width: width, height: height))
        #expect(try await presentationTimes(of: video, in: asset).count == frameCount)
        try await expectDuration(of: asset, seconds: 16.0 / 30, fps: 30)

        let audio = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let sound = try #require(try await audio.load(.formatDescriptions).first.flatMap {
            CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee
        })
        #expect(sound.mFormatID == kAudioFormatMPEG4AAC)
        let bitRate = Double(try await audio.load(.estimatedDataRate))
        #expect(abs(bitRate - 192_000) <= 192_000 * 0.15)

        let media = MediaFile(path: path, size: size, frameTimes: thirtieths)
        let picture = try AVFoundationDecoder().picture(of: media, atFrame: 3)
        let tolerance = 16.0 / 255
        #expect(zip(pixel(of: picture, x: 16, y: 24), [0.5, 0, 0, 1]).allSatisfy { abs($0 - $1) <= tolerance })
        #expect(zip(pixel(of: picture, x: 40, y: 24), [0, 0, 0, 1]).allSatisfy { abs($0 - $1) <= tolerance })
        #expect(zip(pixel(of: picture, x: 56, y: 24), [0.5, 0.5, 0.5, 1]).allSatisfy { abs($0 - $1) <= tolerance })
    }

    @Test("a compressed video at low quality is smaller than at high quality", arguments: [
        VideoCodec.h264,
        VideoCodec.hevc
    ])
    func ordersVideoQuality(codec: VideoCodec) throws {
        // Given
        let directory = try TemporaryDirectory()
        let sut = AVFoundationEncoder(deadline: Self.deadline)
        let noiseSize = Size(width: 128, height: 96)

        // When
        let sizes = try [EncodeQuality.low, .high].map { quality in
            let path = directory.file("\(quality).mp4")
            let target = EncodeTarget.compressed(path: path, codec: codec, quality: quality, size: noiseSize)
            let writer = try sut.videoWriter(for: target, size: noiseSize, fps: 30, sound: nil)
            for index in 0..<8 {
                try writer.append(noise(width: 128, height: 96, seed: index))
            }
            try writer.finish()

            return try byteCount(of: path)
        }

        // Then
        #expect(sizes[0] < sizes[1])
    }

    // MARK: - Private
    private var size: Size {
        Size(width: Double(width), height: Double(height))
    }

    private var thirtieths: [Double] {
        (0..<frameCount).map { Double($0) / 30 }
    }

    private func frame(
        width: Int = 64,
        height: Int = 48
    ) -> Bitmap {
        var components: [UInt16] = []
        for _ in 0..<height {
            for x in 0..<width {
                components += x < width / 2 ? Self.halfRed : x < width * 3 / 4 ? Self.clear : Self.grey
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

    // A 440 Hz tone at half scale in every channel.
    private func tone(
        seconds: Double,
        sampleRate: Double = 48_000,
        channels: Int = 2
    ) -> SoundBuffer {
        let count = Int(seconds * sampleRate)
        let samples = (0..<count).flatMap { index in
            let level = Float(sin(2 * Double.pi * 440 * Double(index) / sampleRate) * 0.5)

            return [Float](repeating: level, count: channels)
        }

        return SoundBuffer(sampleRate: sampleRate, channels: channels, samples: samples)
    }

    // An opaque 8-bit picture of pseudo random colours, the same for the same seed, which compresses poorly.
    private func noise(
        width: Int,
        height: Int,
        seed: Int
    ) -> Bitmap {
        var state = UInt32(truncatingIfNeeded: seed &* 2_654_435_761 &+ 1)
        var pixels = Data(count: width * height * 4)
        for index in 0..<width * height {
            state = state &* 1_664_525 &+ 1_013_904_223
            pixels[index * 4] = UInt8(truncatingIfNeeded: state >> 24)
            pixels[index * 4 + 1] = UInt8(truncatingIfNeeded: state >> 16)
            pixels[index * 4 + 2] = UInt8(truncatingIfNeeded: state >> 8)
            pixels[index * 4 + 3] = 255
        }

        return Bitmap(width: width, height: height, depth: .eight, bytesPerRow: width * 4, pixels: pixels)
    }

    private func byteCount(of path: String) throws -> Int {
        try #require(try FileManager.default.attributesOfItem(atPath: path)[.size] as? Int)
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

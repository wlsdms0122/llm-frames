//
//  AVFoundationDecoderTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/16/26.
//

import AVFoundation
import CoreGraphics
import Foundation
import Frames
import FramesAVFoundation
import FramesTestMedia
import Testing

// Serialized, since AVAssetReader needs a free thread of the shared pool, which tests reading video at once can
// all hold.
@Suite("AVFoundationDecoder Tests", .serialized)
struct AVFoundationDecoderTests {
    // MARK: - Property
    // A file name, the times frames are written at, the session's start and end, the delay before the video, the
    // first written frame that is presented, and the probed frame times and duration.
    private static let editedVideos: [(String, [Double], Double, Double, Double, Int, [Double], Double)] = [
        ("cut.mov", thirtieths(30), 0.5, 1, 0, 15, thirtieths(15), 0.5),
        ("reordered.mp4", thirtieths(30), 0, 1, 0, 0, thirtieths(30), 1),
        ("delayed.mov", thirtieths(15), 0, 0.5, 0.5, 0, (15..<30).map { Double($0) / 30 }, 1)
    ]

    private let size = Size(width: 320, height: 240)
    private let evenTimes = (0..<30).map { Double($0) / 30 }

    // MARK: - Initializer
    // MARK: - Test
    @Test("a video's probe gives every frame's timestamp as written, its size, duration and frame rate")
    func probesVideo() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("even.mp4")
        try await MovieWriter(size: size, frameTimes: evenTimes, end: 1).write(to: file) { canvas, index in
            canvas.fill(red: 128, green: 128, blue: 128)
            canvas.drawCode(index)
        }
        let sut = AVFoundationDecoder()

        // When
        let probed = try #require(try sut.probedMedia(of: file))

        // Then
        #expect(probed == ProbedMedia(
            kind: .video,
            duration: 1,
            fps: 30,
            frames: evenTimes,
            size: size,
            colorSpace: ProbedColorSpace(
                reading: .formulas(.srgb),
                primaries: 1,
                transfer: 13,
                matrix: 1,
                bitDepth: 8,
                isHighDynamicRange: false
            )
        ))
    }

    @Test("frame i of a video is the picture drawn with number i")
    func readsFrameByIndex() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("even.mp4")
        try await MovieWriter(size: size, frameTimes: evenTimes, end: 1).write(to: file) { canvas, index in
            canvas.fill(red: 128, green: 128, blue: 128)
            canvas.drawCode(index)
            canvas.draw("\(index)", font: "Helvetica-Bold", size: 96, x: 120, y: 80)
        }
        let sut = AVFoundationDecoder()
        let media = MediaFile(path: file, size: size, frameTimes: evenTimes)

        // When
        let pictures = try evenTimes.indices.map { try sut.picture(of: media, atFrame: $0) }

        // Then
        #expect(pictures.map(code) == Array(evenTimes.indices))
        #expect(pictures.allSatisfy { $0.width == 320 && $0.height == 240 && $0.depth == .halfFloat })
    }

    @Test("a video written at uneven times keeps its real timestamps, and its frames are read by them")
    func keepsVariableFrameTimes() async throws {
        // Given
        let times = [0, 0.05, 0.1, 0.3, 0.35, 0.6, 0.65, 1.2]
        let directory = try TemporaryDirectory()
        let file = directory.file("variable.mov")
        try await MovieWriter(size: size, frameTimes: times, end: 1.5).write(to: file) { canvas, index in
            canvas.fill(red: 128, green: 128, blue: 128)
            canvas.drawCode(index)
        }
        let sut = AVFoundationDecoder()

        // When
        let probed = try #require(try sut.probedMedia(of: file))
        let media = MediaFile(path: file, size: size, frameTimes: probed.frames)
        let pictures = try times.indices.map { try sut.picture(of: media, atFrame: $0) }

        // Then
        #expect(probed.frames == times)
        #expect(probed.duration == 1.5)
        #expect(pictures.map(code) == Array(times.indices))
    }

    @Test(
        "through a moving edit list, frames keep the times they are presented at and frame i is the i-th presented",
        arguments: editedVideos
    )
    func readsThroughEditList(
        name: String,
        written: [Double],
        start: Double,
        end: Double,
        delay: Double,
        firstPresented: Int,
        frames: [Double],
        duration: Double
    ) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file(name)
        let writer = MovieWriter(size: size, frameTimes: written, start: start, end: end, delay: delay)
        try await writer.write(to: file) { canvas, index in
            canvas.fill(red: 128, green: 128, blue: 128)
            canvas.drawCode(index < firstPresented ? 63 : index - firstPresented)
        }
        let sut = AVFoundationDecoder()

        // When
        let probed = try #require(try sut.probedMedia(of: file))
        let media = MediaFile(path: file, size: size, frameTimes: probed.frames)
        let pictures = try probed.frames.indices.map { try sut.picture(of: media, atFrame: $0) }

        // Then
        #expect(try await edits(of: file).contains { $0.source.start != $0.target.start })
        #expect(probed.frames == frames)
        #expect(probed.duration == duration)
        #expect(pictures.map(code) == Array(frames.indices))
    }

    @Test("a turned video reports the size it is displayed at, and its pictures are turned the same way")
    func turnsVideoForDisplay() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("portrait.mov")
        let quarterTurn = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 240, ty: 0)
        let writer = MovieWriter(size: size, frameTimes: [0, 0.5], end: 1, transform: quarterTurn)
        try await writer.write(to: file) { canvas, index in
            canvas.fill(red: 128, green: 128, blue: 128)
            canvas.drawCode(index + 5)
            canvas.fill(Rectangle(x: 0, y: 280, width: 240, height: 40), red: 255, green: 0, blue: 0)
        }
        let sut = AVFoundationDecoder()

        // When
        let probed = try #require(try sut.probedMedia(of: file))
        let picture = try sut.picture(of: MediaFile(path: file, frameTimes: probed.frames), atFrame: 1)

        // Then
        #expect(probed.size == Size(width: 240, height: 320))
        #expect(picture.width == 240 && picture.height == 320)
        #expect(code(in: picture) == 6)
        #expect(pixel(in: picture, x: 120, y: 300)[0] > 200)
        #expect(pixel(in: picture, x: 120, y: 20)[0] < 200)
    }

    @Test("a video with a sound track has sound, and one without has none", arguments: [true, false])
    func tellsSound(sound: Bool) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("sound.mov")
        try await MovieWriter(size: size, frameTimes: evenTimes, end: 1, sound: sound).write(to: file) { canvas, _ in
            canvas.fill(red: 128, green: 128, blue: 128)
        }
        let sut = AVFoundationDecoder()

        // When
        let probed = try #require(try sut.probedMedia(of: file))

        // Then
        #expect(probed.sound == (sound ? ProbedSound(channels: 1, sampleRate: 48_000) : nil))
        #expect(probed.frames == evenTimes)
    }

    @Test(
        "a sound file's probe gives its first sound track's channel count and sample rate",
        arguments: [(1, 48_000), (2, 44_100), (6, 48_000)]
    )
    func probesSoundFormat(channels: Int, sampleRate: Int) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("tone.m4a")
        let levels = Array(repeating: 0.25, count: channels)
        try await SoundWriter(end: 0.5, sampleRate: sampleRate, levels: levels).write(to: file)
        let sut = AVFoundationDecoder()

        // When
        let probed = try #require(try sut.probedMedia(of: file))

        // Then
        #expect(probed.sound == ProbedSound(channels: channels, sampleRate: Double(sampleRate)))
        #expect(probed.hasAlpha == false)
    }

    @Test("a still and an image sequence carry alpha as their PNGs do, and an H.264 video carries none")
    func tellsAlpha() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let clear = directory.file("clear.png")
        let opaque = directory.file("opaque.png")
        let sequence = directory.file("sequence")
        let frame = (sequence as NSString).appendingPathComponent("1.png")
        let video = directory.file("video.mov")
        try ImageWriter(size: size).write(to: clear) { _ in }
        try ImageWriter(size: size, opaque: true).write(to: opaque) { canvas in
            canvas.fill(red: 128, green: 128, blue: 128)
        }
        try FileManager.default.createDirectory(atPath: sequence, withIntermediateDirectories: false)
        try ImageWriter(size: size, opaque: true).write(to: frame) { _ in }
        try await MovieWriter(size: size, frameTimes: [0], end: 0.1).write(to: video) { canvas, _ in
            canvas.fill(red: 128, green: 128, blue: 128)
        }
        let sut = AVFoundationDecoder()

        // When
        let clearAlpha = try #require(try sut.probedMedia(of: clear)).hasAlpha
        let opaqueAlpha = try #require(try sut.probedMedia(of: opaque)).hasAlpha
        let sequenceAlpha = try #require(try sut.probedImageSequence(at: sequence)).hasAlpha
        let videoAlpha = try #require(try sut.probedMedia(of: video)).hasAlpha

        // Then
        #expect(clearAlpha && !opaqueAlpha && !sequenceAlpha && !videoAlpha)
    }

    // A sound file is probed by loads alone, where a video's probe also reads its samples with AVAssetReader, which
    // needs a free thread of the pool.
    @Test(
        "probes of a sound file from more tasks at once than the shared pool has threads all finish",
        .timeLimit(.minutes(1))
    )
    func probesConcurrently() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("tone.m4a")
        try await SoundWriter(end: 1).write(to: file)
        let sut = (0..<ProcessInfo.processInfo.activeProcessorCount * 4).map { _ in AVFoundationDecoder() }

        // When
        let probed = try await withThrowingTaskGroup(of: ProbedMedia?.self) { group in
            for decoder in sut {
                group.addTask { try decoder.probedMedia(of: file) }
            }

            return try await group.reduce(into: []) { $0.append($1) }
        }

        // Then
        #expect(probed.count == sut.count)
        #expect(probed.allSatisfy { $0?.kind == .audio && $0?.hasSound == true })
    }

    @Test("a still has one frame at its size")
    func readsStill() throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("card.png")
        try ImageWriter(size: Size(width: 200, height: 100)).write(to: file) { canvas in
            canvas.fill(red: 128, green: 128, blue: 128)
            canvas.drawCode(37)
        }
        let sut = AVFoundationDecoder()

        // When
        let probed = try #require(try sut.probedMedia(of: file))
        let picture = try sut.picture(of: MediaFile(path: file), atFrame: 0)

        // Then
        #expect(probed.kind == .image && probed.size == Size(width: 200, height: 100) && probed.hasAlpha)
        #expect(probed.colorSpace?.name == .srgb)
        #expect(picture.width == 200 && picture.height == 100)
        #expect(code(in: picture) == 37)
        let error = #expect(throws: DecoderError.self) { try sut.picture(of: MediaFile(path: file), atFrame: 1) }
        #expect(error?.description == "media \(file) has no frame 1: it has 1")
    }

    @Test("pictures are working values with premultiplied alpha, a 16 bit still read as half floats")
    func convertsToWorkingSpace() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let video = directory.file("patch.mov")
        let still = directory.file("patch.png")
        let deep = directory.file("deep.png")
        try await MovieWriter(size: size, frameTimes: [0], end: 1).write(to: video) { canvas, _ in
            canvas.fill(red: 200, green: 120, blue: 40)
        }
        try ImageWriter(size: size).write(to: still) { canvas in
            canvas.fill(red: 200, green: 120, blue: 40)
            canvas.context.clear(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        try ImageWriter(size: size, bitsPerComponent: 16).write(to: deep) { canvas in
            canvas.fill(red: 200, green: 120, blue: 40)
        }
        let sut = AVFoundationDecoder()

        // When
        let videoPicture = try sut.picture(of: MediaFile(path: video), atFrame: 0)
        let stillPicture = try sut.picture(of: MediaFile(path: still), atFrame: 0)
        let deepPicture = try sut.picture(of: MediaFile(path: deep), atFrame: 0)

        // Then
        let videoPixel = pixel(in: videoPicture, x: 160, y: 120)
        #expect(zip(videoPixel, [200, 120, 40, 255]).allSatisfy { abs($0 - $1) <= 3 }, "\(videoPixel)")
        #expect(pixel(in: stillPicture, x: 160, y: 120) == [200, 120, 40, 255])
        #expect(pixel(in: stillPicture, x: 5, y: 235) == [0, 0, 0, 0])
        #expect(deepPicture.depth == .halfFloat)
        #expect(deepPicture.bytesPerRow == 320 * 8)
    }

    @Test("an image sequence holds its PNG files in natural order, each the picture of its frame")
    func readsImageSequence() throws {
        // Given
        let directory = try TemporaryDirectory()
        for number in [1, 2, 10, 9] {
            try ImageWriter(size: size).write(to: directory.file("frame\(number).png")) { canvas in
                canvas.fill(red: 128, green: 128, blue: 128)
                canvas.drawCode(number)
            }
        }
        try Data().write(to: URL(fileURLWithPath: directory.file("notes.txt")))
        let sut = AVFoundationDecoder()

        // When
        let probed = try #require(try sut.probedImageSequence(at: directory.path))
        let media = MediaFile(path: directory.path, size: probed.size, frameFiles: probed.files)
        let pictures = try probed.files.indices.map { try sut.picture(of: media, atFrame: $0) }

        // Then
        #expect(probed.files == [1, 2, 9, 10].map { directory.file("frame\($0).png") })
        #expect(probed.size == size)
        #expect(pictures.map(code) == [1, 2, 9, 10])
    }

    @Test("an image sequence whose frames differ in size stops, naming the first frame that differs and both sizes")
    func refusesUnequalImageSequence() throws {
        // Given
        let directory = try TemporaryDirectory()
        try ImageWriter(size: size).write(to: directory.file("frame1.png")) { _ in }
        try ImageWriter(size: size).write(to: directory.file("frame2.png")) { _ in }
        try ImageWriter(size: Size(width: 321, height: 240)).write(to: directory.file("frame3.png")) { _ in }
        try ImageWriter(size: Size(width: 322, height: 240)).write(to: directory.file("frame4.png")) { _ in }
        let sut = AVFoundationDecoder()

        // When
        let error = #expect(throws: DecoderError.self) { try sut.probedImageSequence(at: directory.path) }

        // Then
        #expect(
            error?.description
                == "image sequence frame \(directory.file("frame3.png")) is 321x240, where the first frame is 320x240"
        )
    }

    @Test("a file with only sound is probed as sound, past the check for a picture track")
    func probesSound() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("tone.m4a")
        try await SoundWriter(end: 1).write(to: file)
        let sut = AVFoundationDecoder()

        // When
        let probed = try #require(try sut.probedMedia(of: file))

        // Then
        #expect(probed.kind == .audio && probed.hasSound && probed.frames.isEmpty && probed.size == nil)
        #expect(abs(probed.duration - 1) < 0.05, "\(probed.duration)")
    }

    @Test("media that is not there has no facts, and a file that is there but is no media stops, saying why")
    func refusesUnreadableMedia() throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("broken.mp4")
        try Data("not a video".utf8).write(to: URL(fileURLWithPath: file))
        let sut = AVFoundationDecoder()

        // When
        let absent = try sut.probedMedia(of: directory.file("absent.mp4"))
        let absentSequence = try sut.probedImageSequence(at: directory.file("absent"))
        let error = #expect(throws: DecoderError.self) { try sut.probedMedia(of: file) }

        // Then
        #expect(absent == nil && absentSequence == nil)
        #expect(error?.description.hasPrefix("media \(file) cannot be read") == true, "\(String(describing: error))")
    }

    @Test("a video whose frames count differently from the pinned timestamps stops")
    func stopsOnPinnedCount() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("even.mp4")
        try await MovieWriter(size: size, frameTimes: evenTimes, end: 1).write(to: file) { _, _ in }
        let sut = AVFoundationDecoder()

        // When
        let error = #expect(throws: DecoderError.self) {
            try sut.picture(of: MediaFile(path: file, frameTimes: [0, 0.5]), atFrame: 0)
        }

        // Then
        #expect(
            error?.description == "media \(file) has 30 frames where the resolved document pins 2. Resolve it again"
        )
    }

    @Test("checking a file before rendering refuses a miscounted video and passes one counted as pinned")
    func checksPinnedCount() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("even.mp4")
        try await MovieWriter(size: size, frameTimes: evenTimes, end: 1).write(to: file) { _, _ in }
        let sut = AVFoundationDecoder()

        // When
        let error = #expect(throws: DecoderError.self) {
            try sut.check(MediaFile(path: file, frameTimes: [0, 0.5]), reading: .tagged)
        }

        // Then
        #expect(
            error?.description == "media \(file) has 30 frames where the resolved document pins 2. Resolve it again"
        )
        #expect(throws: Never.self) { try sut.check(MediaFile(path: file, frameTimes: evenTimes), reading: .tagged) }
    }

    @Test("checking a file passes one with only sound, and still refuses one that is no media")
    func checksSoundFile() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let sound = directory.file("tone.m4a")
        let broken = directory.file("broken.mp4")
        try await SoundWriter(end: 1).write(to: sound)
        try Data("not a video".utf8).write(to: URL(fileURLWithPath: broken))
        let sut = AVFoundationDecoder()

        // When
        let error = #expect(throws: DecoderError.self) { try sut.check(MediaFile(path: broken), reading: nil) }

        // Then
        #expect(throws: Never.self) { try sut.check(MediaFile(path: sound), reading: nil) }
        #expect(error?.description.hasPrefix("media \(broken) cannot be read") == true, "\(String(describing: error))")
    }

    @Test("sound over a sub-range has the file's rate and channels, its frame count, and the tone's samples at their time")
    func readsSoundRange() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("stereo.wav")
        let writer = SoundWriter(end: 1, sampleRate: 44_100, levels: [0.25, 0.1])
        try await writer.write(to: file)
        let sut = AVFoundationDecoder()

        // When
        let sound = try sut.sound(of: MediaFile(path: file), from: 0.25, to: 0.75)

        // Then
        #expect(sound.sampleRate == 44_100 && sound.channels == 2 && sound.layout.labels == [.left, .right])
        #expect(sound.frameCount == 22_050)
        let deviation = (0..<sound.frameCount).flatMap { frame in
            (0..<2).map { channel in
                abs(Double(sound.samples[frame * 2 + channel]) - writer.sample(channel: channel, at: 11_025 + frame))
            }
        }.max()!
        #expect(deviation < 1.0 / 32_768, "\(deviation)")
    }

    @Test("a file of two sound tracks has the first one's sound, and the other is not read")
    func readsFirstSoundTrack() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("tracks.mov")
        let first = SoundWriter(end: 0.5, levels: [0.25])
        let second = SoundWriter(end: 0.5, signal: .noise(seed: 1), levels: [0.5, 0.5])
        try await MultitrackSoundWriter(end: 0.5, tracks: [first, second]).write(to: file)
        let sut = AVFoundationDecoder()

        // When
        let sound = try sut.sound(of: MediaFile(path: file), from: 0, to: 0.5)

        // Then
        #expect(sound.channels == 1 && sound.layout.labels == [.mono])
        #expect(sound.frameCount == 24_000)
        let deviation = (0..<sound.frameCount).map { frame in
            abs(Double(sound.samples[frame]) - first.sample(channel: 0, at: frame))
        }.max()!
        #expect(deviation < 1.0 / 32_768, "\(deviation)")
    }

    @Test("an AAC file's sound has its rate, channel count and frames over a sub-range, the tone at its level")
    func readsAACSound() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("tone.m4a")
        try await SoundWriter(end: 1).write(to: file)
        let sut = AVFoundationDecoder()

        // When
        let sound = try sut.sound(of: MediaFile(path: file), from: 0.25, to: 0.5)

        // Then
        #expect(sound.sampleRate == 48_000 && sound.channels == 1 && sound.layout.labels == [.mono])
        #expect(sound.frameCount == 12_000)
        #expect(abs(Double(sound.samples.map(abs).max()!) - 8_000.0 / 32_768) < 0.01)
    }

    @Test("a range past the end of the sound gives the frames there are, and an empty range none")
    func readsPastEnd() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        try await SoundWriter(end: 1).write(to: file)
        let sut = AVFoundationDecoder()

        // When
        let past = try sut.sound(of: MediaFile(path: file), from: 0.5, to: 2)
        let empty = try sut.sound(of: MediaFile(path: file), from: 0.5, to: 0.5)

        // Then
        #expect(past.frameCount == 24_000)
        #expect(empty.frameCount == 0 && empty.sampleRate == 48_000 && empty.channels == 1)
    }

    @Test("a 5.1 file's channels are named in its layout's order")
    func readsSurroundLayout() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("surround.wav")
        try await SoundWriter(end: 0.1, levels: Array(repeating: 0.1, count: 6)).write(to: file)
        let sut = AVFoundationDecoder()

        // When
        let sound = try sut.sound(of: MediaFile(path: file), from: 0, to: 0.1)

        // Then
        #expect(sound.channels == 6)
        #expect(sound.layout.labels == [.left, .right, .center, .lowFrequencyEffects, .leftSurround, .rightSurround])
    }

    @Test("sound is read on the presentation timeline, so a video delayed by its edit list has silence first")
    func readsSoundThroughEditList() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("delayed.mov")
        let writer = MovieWriter(size: size, frameTimes: Self.thirtieths(15), end: 0.5, sound: true, delay: 0.5)
        try await writer.write(to: file) { canvas, _ in
            canvas.fill(red: 128, green: 128, blue: 128)
        }
        let sut = AVFoundationDecoder()

        // When
        let sound = try sut.sound(of: MediaFile(path: file), from: 0, to: 1)

        // Then
        #expect(sound.frameCount > 47_000)
        #expect(sound.samples[0..<21_600].map(abs).max()! < 0.01)
        #expect(sound.samples[26_400..<45_600].map(abs).max()! > 0.2)
    }

    @Test("a file without a sound track has no sound, naming the file")
    func refusesSilentSound() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("silent.mov")
        try await MovieWriter(size: size, frameTimes: [0], end: 1).write(to: file) { _, _ in }
        let sut = AVFoundationDecoder()

        // When
        let error = #expect(throws: DecoderError.self) { try sut.sound(of: MediaFile(path: file), from: 0, to: 1) }

        // Then
        #expect(error?.description == "media \(file) has no sound track")
    }

    @Test("frames read in order, again, and after jumps back and far ahead are the pixels of fresh reads")
    func readsForward() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("long.mp4")
        let times = (0..<90).map { Double($0) / 30 }
        let writer = MovieWriter(size: size, frameTimes: times, end: 3, keyFrameInterval: 10)
        try await writer.write(to: file) { canvas, index in
            canvas.fill(red: Double(40 + index), green: 128, blue: Double(200 - index))
            canvas.drawCode(index % 64)
        }
        let media = MediaFile(path: file, frameTimes: times)
        let order = Array(0..<45) + [44, 44, 12, 13, 14, 80, 81, 3]
        let sut = AVFoundationDecoder()

        // When
        let pictures = try order.map { try sut.picture(of: media, atFrame: $0) }

        // Then
        let fresh = try order.map { try AVFoundationDecoder().picture(of: media, atFrame: $0) }
        #expect(pictures == fresh)
        #expect(pictures.map(code) == order.map { $0 % 64 })
    }

    // MARK: - Private
    private static func thirtieths(_ count: Int) -> [Double] {
        (0..<count).map { Double($0) / 30 }
    }

    // The edits of the file's picture track, an empty one with no source start.
    private func edits(of file: String) async throws -> [CMTimeMapping] {
        let asset = AVURLAsset(url: URL(fileURLWithPath: file))
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)

        return try await track.load(.segments).map(\.timeMapping)
    }

    // The number `Canvas.drawCode` drew at the top left.
    private func code(in picture: Bitmap) -> Int {
        (0..<6).reduce(0) { value, bit in
            pixel(in: picture, x: bit * 16 + 8, y: 8)[0] > 128 ? value | 1 << bit : value
        }
    }

    // The RGBA components at a pixel, each as its nearest 8 bit code value.
    private func pixel(
        in picture: Bitmap,
        x: Int,
        y: Int
    ) -> [Int] {
        guard picture.depth == .halfFloat else {
            let start = y * picture.bytesPerRow + x * 4

            return picture.pixels[start..<start + 4].map(Int.init)
        }

        let start = y * picture.bytesPerRow + x * 8
        return picture.pixels[start..<start + 8].withUnsafeBytes { bytes in
            bytes.bindMemory(to: Float16.self).map { Int((Double($0) * 255).rounded()) }
        }
    }
}

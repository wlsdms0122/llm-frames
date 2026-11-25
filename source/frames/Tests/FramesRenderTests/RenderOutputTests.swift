//
//  RenderOutputTests.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/17/26.
//

import AVFoundation
import Foundation
import FramesAVFoundation
import FramesQuartz
import FramesTestMedia
import Testing

@testable import Frames

// Masters and deliveries written by `RenderPipeline` on the real roles, read back through AVFoundation and the
// decoder. Serialized, since AVAssetReader needs a free thread of the shared pool and each test encodes.
@Suite("Render Output Tests", .serialized, .timeLimit(.minutes(5)))
struct RenderOutputTests {
    // MARK: - Property
    // These tests read the files a render leaves and none of them is about how long a writer takes, so the encoder
    // waits on its writers without a deadline, and the suite's time limit ends a writer that never finishes.
    private static let deadline = Double.infinity

    // ProRes 422 HQ subsamples colour and H.264 compresses it, so a flat colour comes back to within a few steps.
    private let tolerance = 6.0 / 255

    // MARK: - Initializer
    // MARK: - Test
    @Test("the first frame of the master and of the delivery shows the storyline and the clip visible from 0")
    func showsFirstFrame() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let storyline = try image(in: media, named: "orange.png", width: 160, height: 90, color: [255, 128, 0])
        let clip = try image(in: media, named: "blue.png", width: 40, height: 30, color: [0, 0, 255])
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 },
              "storyline": [ { "kind": "media", "media": "\#(storyline)", "duration": 0.5 } ],
              "clips": [ { "at": [0, 0.5], "kind": "media", "media": "\#(clip)", "width": 40 } ] }
            """#)
        let box = try #require(Evaluator().displayList(of: document, at: 0).placedPictures(named: "blue.png").first)
        let sut = pipeline()

        // When
        try sut.render(document, to: output.file("out.mov"), at: nil, delivery: output.file("out.mp4"))

        // Then
        let decoder = AVFoundationDecoder()
        for name in ["out.mov", "out.mp4"] {
            let frame = try decoder.picture(of: MediaFile(path: output.file(name)), atFrame: 0)
            let centre = (Int(box.center.x), Int(box.center.y))
            #expect(
                frame.isPixel(x: centre.0, y: centre.1, [0, 0, 255], tolerance: tolerance),
                "\(name): \(frame.pixel(x: centre.0, y: centre.1))"
            )
            #expect(
                frame.isPixel(x: 8, y: 8, [255, 128, 0], tolerance: tolerance),
                "\(name): \(frame.pixel(x: 8, y: 8))"
            )
        }
    }

    @Test("the master and the delivery last the sequence's duration to within one frame, sound and picture alike")
    func lastsDuration() async throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let file = try image(in: media, named: "grey.png", width: 160, height: 90, color: [128, 128, 128])
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 }, "storyline": [ { "kind": "media", "media": "\#(file)", "duration": 2.25 } ] }
            """#)
        let sut = pipeline()

        // When
        try sut.render(document, to: output.file("out.mov"), at: nil, delivery: output.file("out.mp4"))

        // Then
        // Frames 0 to 22 start before 2.25, so the output plays 2.3 seconds, longer than the writer interleaves at
        // once.
        let decoder = AVFoundationDecoder()
        for name in ["out.mov", "out.mp4"] {
            let probed = try #require(try decoder.probedMedia(of: output.file(name)))
            #expect(probed.frames.count == 23, "\(name)")
            #expect(abs(probed.duration - 2.25) <= 0.1, "\(name) lasts \(probed.duration)")

            let asset = AVURLAsset(url: URL(fileURLWithPath: output.file(name)))
            let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
            let audio = try #require(try await asset.loadTracks(withMediaType: .audio).first)
            let pictureLength = CMTimeGetSeconds(try await video.load(.timeRange).duration)
            let soundLength = CMTimeGetSeconds(try await audio.load(.timeRange).duration)
            #expect(abs(soundLength - pictureLength) <= 0.1, "\(name): sound \(soundLength), picture \(pictureLength)")
        }
    }

    @Test(
        "the master is ProRes with 24 bit PCM, 4444 when the background is not opaque, and the delivery H.264 with AAC",
        arguments: [
            ("#000000", kCMVideoCodecType_AppleProRes422HQ),
            ("#00000000", kCMVideoCodecType_AppleProRes4444)
        ]
    )
    func encodesCodecs(
        background: String,
        masterCodec: CMVideoCodecType
    ) async throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let file = try image(in: media, named: "grey.png", width: 160, height: 90, color: [128, 128, 128])
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10, "background": "\#(background)" },
              "storyline": [ { "kind": "media", "media": "\#(file)", "duration": 0.5 } ] }
            """#)
        let sut = pipeline()

        // When
        try sut.render(document, to: output.file("out.mov"), at: nil, delivery: output.file("out.mp4"))

        // Then
        let master = try await formats(of: output.file("out.mov"))
        #expect(master.video == masterCodec)
        #expect(master.audio.mFormatID == kAudioFormatLinearPCM)
        #expect(master.audio.mBitsPerChannel == 24)
        #expect(master.audio.mSampleRate == 48_000 && master.audio.mChannelsPerFrame == 2)

        let delivery = try await formats(of: output.file("out.mp4"))
        #expect(delivery.video == kCMVideoCodecType_H264)
        #expect(delivery.audio.mFormatID == kAudioFormatMPEG4AAC)
        #expect(delivery.audio.mSampleRate == 48_000 && delivery.audio.mChannelsPerFrame == 2)
    }

    @Test("an MP4 output is the one file written, in the codecs and with the frames of a delivery beside a master")
    func rendersDeliveryAlone() async throws {
        // Given
        let media = try TemporaryDirectory()
        let beside = try TemporaryDirectory()
        let alone = try TemporaryDirectory()
        let storyline = try image(in: media, named: "orange.png", width: 160, height: 90, color: [255, 128, 0])
        let clip = try image(in: media, named: "blue.png", width: 40, height: 30, color: [0, 0, 255])
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 },
              "storyline": [ { "kind": "media", "media": "\#(storyline)", "duration": 0.5 } ],
              "clips": [ { "at": [0, 0.5], "kind": "media", "media": "\#(clip)", "width": 40 } ] }
            """#)
        let box = try #require(Evaluator().displayList(of: document, at: 0).placedPictures(named: "blue.png").first)
        let sut = pipeline()

        // When
        try sut.render(document, to: beside.file("out.mov"), at: nil, delivery: beside.file("out.mp4"))
        try sut.render(document, to: alone.file("out.mp4"), at: nil, delivery: nil)

        // Then
        #expect(try contents(of: alone) == ["out.mp4"])

        let written = try await formats(of: alone.file("out.mp4"))
        let delivered = try await formats(of: beside.file("out.mp4"))
        #expect(written.video == kCMVideoCodecType_H264 && written.video == delivered.video)
        #expect(written.audio.mFormatID == kAudioFormatMPEG4AAC && written.audio.mFormatID == delivered.audio.mFormatID)
        #expect(written.audio.mSampleRate == delivered.audio.mSampleRate)
        #expect(written.audio.mChannelsPerFrame == delivered.audio.mChannelsPerFrame)

        let decoder = AVFoundationDecoder()
        let frame = try decoder.picture(of: MediaFile(path: alone.file("out.mp4")), atFrame: 0)
        let centre = (Int(box.center.x), Int(box.center.y))
        #expect(
            frame.isPixel(x: centre.0, y: centre.1, [0, 0, 255], tolerance: tolerance),
            "\(frame.pixel(x: centre.0, y: centre.1))"
        )
        #expect(frame.isPixel(x: 8, y: 8, [255, 128, 0], tolerance: tolerance), "\(frame.pixel(x: 8, y: 8))")
    }

    @Test("a document whose pinned file changed since it was resolved is refused, and nothing is written")
    func refusesChangedFile() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let file = try image(in: media, named: "grey.png", width: 160, height: 90, color: [128, 128, 128])
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 }, "storyline": [ { "kind": "media", "media": "\#(file)", "duration": 0.5 } ] }
            """#)
        _ = try image(in: media, named: "grey.png", width: 160, height: 90, color: [129, 128, 128])
        let sut = pipeline()

        // When
        let error = #expect(throws: PinnedReferenceError.self) {
            try sut.render(document, to: output.file("out.mov"), at: nil, delivery: output.file("out.mp4"))
        }

        // Then
        guard case let .changedFile(_, place) = error else {
            Issue.record("refused with \(String(describing: error))")
            return
        }
        #expect(place == "storyline[0]")
        #expect(try contents(of: output).isEmpty)
    }

    @Test("a document asking a role for what it lacks is refused before the first frame, and nothing is written")
    func refusesLackingRole() async throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let file = try image(in: media, named: "grey.png", width: 160, height: 90, color: [128, 128, 128])
        let tone = media.file("tone.wav")
        try await SoundWriter(end: 1).write(to: tone)
        // The avfoundation mixer stretches time from 1/32 to 32 times.
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 }, "storyline": [ { "kind": "media", "media": "\#(file)", "duration": 0.5 } ],
              "clips": [ { "kind": "audio", "media": "\#(tone)", "speed": 40 } ] }
            """#)
        let sut = pipeline()

        // When
        let error = #expect(throws: MixerError.self) {
            try sut.render(document, to: output.file("out.mov"), at: nil, delivery: output.file("out.mp4"))
        }

        // Then
        guard case let .unstretchable(segment, _, speed) = error else {
            Issue.record("refused with \(String(describing: error))")
            return
        }
        #expect(segment == "segments[0]" && speed == 40)
        #expect(try contents(of: output).isEmpty)
    }

    @Test("a render leaves only its master and delivery, and a render that fails half way leaves nothing")
    func leavesNoTemporaryFile() throws {
        // Given
        let media = try TemporaryDirectory()
        let finished = try TemporaryDirectory()
        let failed = try TemporaryDirectory()
        let file = try image(in: media, named: "grey.png", width: 160, height: 90, color: [128, 128, 128])
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "fps": 10 }, "storyline": [ { "kind": "media", "media": "\#(file)", "duration": 1 } ] }
            """#)
        let sut = pipeline()
        let failing = pipeline(failingAtFrame: 4)

        // When
        try sut.render(document, to: finished.file("out.mov"), at: nil, delivery: finished.file("out.mp4"))
        #expect(throws: InjectedFailure.frame(4)) {
            try failing.render(document, to: failed.file("out.mov"), at: nil, delivery: failed.file("out.mp4"))
        }

        // Then
        #expect(try contents(of: finished) == ["out.mov", "out.mp4"])
        #expect(try contents(of: failed).isEmpty)
    }

    @Test("the frame at --at renders to one PNG at the frame's size and leaves nothing else", arguments: [
        (0.5, [128, 128, 128] as [Double]),
        (1.5, [255, 0, 0])
    ])
    func rendersFrameToOnePNG(
        time: Double,
        color: [Double]
    ) throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let file = try image(in: media, named: "grey.png", width: 160, height: 90, color: [128, 128, 128])
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "size": [160, 90] },
              "storyline": [ { "kind": "media", "media": "\#(file)", "duration": 1 }, { "kind": "solid", "color": "#FF0000", "duration": 1 } ] }
            """#)
        let sut = pipeline()

        // When
        try sut.render(document, to: output.file("out.png"), at: time, delivery: nil)

        // Then
        #expect(try contents(of: output) == ["out.png"])
        let picture = try AVFoundationDecoder().picture(of: MediaFile(path: output.file("out.png")), atFrame: 0)
        #expect(picture.width == 160 && picture.height == 90)
        #expect(picture.isPixel(x: 80, y: 45, color, tolerance: 1.0 / 255))
    }

    @Test("a frame that fits its content renders to a PNG at the measured size, the margin showing the background")
    func rendersContentFitToPNG() throws {
        // Given
        let media = try TemporaryDirectory()
        let output = try TemporaryDirectory()
        let file = try image(in: media, named: "grey.png", width: 160, height: 90, color: [128, 128, 128])
        let document = try DocumentResolver().resolve(#"""
            { "kind": "sequence", "format": { "size": { "fit": "content", "margin": [10, 20] } },
              "storyline": [ { "kind": "media", "media": "\#(file)", "duration": 1 } ] }
            """#)
        let sut = pipeline()

        // When
        try sut.render(document, to: output.file("out.png"), at: 0, delivery: nil)

        // Then
        let picture = try AVFoundationDecoder().picture(of: MediaFile(path: output.file("out.png")), atFrame: 0)
        #expect(picture.width == 200 && picture.height == 110)
        #expect(picture.isPixel(x: 100, y: 55, [128, 128, 128], tolerance: 1.0 / 255))
        #expect(picture.isPixel(x: 10, y: 55, [0, 0, 0], tolerance: 1.0 / 255))
        #expect(picture.isPixel(x: 100, y: 5, [0, 0, 0], tolerance: 1.0 / 255))
    }

    // MARK: - Private
    private func pipeline(failingAtFrame failure: Int? = nil) -> RenderPipeline {
        let decoder = AVFoundationDecoder()
        let renderer = QuartzRenderer(decoder: decoder)

        return RenderPipeline(
            decoder: decoder,
            renderer: failure.map { FailingRenderer(renderer: renderer, failingAt: $0) } ?? renderer,
            mixer: AVFoundationMixer(decoder: decoder),
            encoder: AVFoundationEncoder(deadline: Self.deadline)
        )
    }

    private func image(
        in directory: TemporaryDirectory,
        named name: String,
        width: Double,
        height: Double,
        color: [Double]
    ) throws -> String {
        let file = directory.file(name)
        try ImageWriter(size: Size(width: width, height: height)).write(to: file) { canvas in
            canvas.fill(red: color[0], green: color[1], blue: color[2])
        }

        return file
    }

    private func contents(of directory: TemporaryDirectory) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    // The codec of the first video track and the stream description of the first audio track.
    private func formats(
        of path: String
    ) async throws -> (video: CMVideoCodecType, audio: AudioStreamBasicDescription) {
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let audio = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let videoFormat = try #require(try await video.load(.formatDescriptions).first)
        let audioFormat = try #require(try await audio.load(.formatDescriptions).first)
        let description = try #require(CMAudioFormatDescriptionGetStreamBasicDescription(audioFormat)?.pointee)

        return (CMFormatDescriptionGetMediaSubType(videoFormat), description)
    }
}

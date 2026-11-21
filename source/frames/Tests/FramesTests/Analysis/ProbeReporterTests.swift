//
//  ProbeReporterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesAVFoundation
import FramesTestMedia
import Testing

@testable import Frames

// Serialized, since AVAssetReader needs a free thread of the shared pool, which tests reading video at once can
// all hold.
@Suite("ProbeReporter Tests", .serialized)
struct ProbeReporterTests {
    // MARK: - Property
    private let sut = ProbeReporter(mediaFacts: Fixture.mediaFacts)

    // MARK: - Initializer
    // MARK: - Test
    @Test("the machine output is the probe object FRAMES-23 gives, the duration to the microsecond, with colour facts")
    func writesMachineOutput() throws {
        // Given
        let facts = MediaFactTable(files: [
            "/abs/run.mp4": ProbedMedia(
                kind: .video,
                duration: 2.0000004,
                fps: 29.97,
                size: Size(width: 1080, height: 1920),
                colorSpace: ProbedColorSpace(
                    reading: .formulas(.rec2100PQ),
                    primaries: 9,
                    transfer: 16,
                    matrix: 9,
                    bitDepth: 10,
                    isHighDynamicRange: true
                ),
                sound: ProbedSound(channels: 2, sampleRate: 48_000)
            )
        ])
        let sut = ProbeReporter(mediaFacts: facts)

        // When
        let report = try sut.report(of: "/abs/run.mp4")

        // Then
        let expected = #"""
            {"probe": "1.0.0", "kind": "video", "size": [1080, 1920], "duration": 2, "fps": 29.97, "alpha": false, \#
            "colorSpace": {"name": "rec2100-pq", "primaries": 9, "transfer": 16, "matrix": 9, "bitDepth": 10, \#
            "hdr": true}, "audio": {"channels": 2, "sampleRate": 48000}, "pages": null}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("what a medium does not have is null: an image's duration and rate, and sound's size and rate")
    func writesNullForMissingFacts() throws {
        // Given
        let image = "/abs/card.png"
        let sound = "/abs/ding.wav"

        // When
        let imageOutput = try sut.report(of: image).machineOutput.objectValue
        let soundOutput = try sut.report(of: sound).machineOutput.objectValue

        // Then
        #expect(imageOutput?["kind"] == .string("image"))
        #expect(imageOutput?["duration"] == .null && imageOutput?["fps"] == .null && imageOutput?["audio"] == .null)
        #expect(soundOutput?["kind"] == .string("audio"))
        #expect(soundOutput?["size"] == .null && soundOutput?["fps"] == .null && soundOutput?["colorSpace"] == .null)
        #expect(soundOutput?["audio"] == .object(JSONObject(members: [
            JSONMember(key: "channels", value: .number(1)),
            JSONMember(key: "sampleRate", value: .number(44_100))
        ])))
    }

    @Test("a still has no duration, a page of a PDF as an image")
    func writesNoDurationForStill() {
        // Given
        let page = ProbedMedia(kind: .page, duration: 5, size: Size(width: 595.276, height: 841.89))

        // When
        let report = ProbeReport(page)

        // Then
        #expect(report.kind == "page")
        #expect(report.duration == nil)
    }

    @Test("a page is probed with its size in points, alpha, srgb with no bits per channel and the page count")
    func writesPage() throws {
        // Given
        let facts = MediaFactTable(
            files: [:],
            pages: ["/abs/deck.pdf": [Size(width: 595.2756, height: 841.8898), Size(width: 100, height: 50)]]
        )
        let sut = ProbeReporter(mediaFacts: facts)

        // When
        let report = try sut.report(of: "/abs/deck.pdf", page: 1)

        // Then
        let expected = #"""
            {"probe": "1.0.0", "kind": "page", "size": [595.2756, 841.8898], "duration": null, "fps": null, \#
            "alpha": true, "colorSpace": {"name": "srgb", "primaries": 1, "transfer": 13, "matrix": null, \#
            "bitDepth": null, "hdr": false}, "audio": null, "pages": 2}
            """#
        #expect(report.machineOutput.written == expected)
        #expect(report.text.contains("color space srgb\naudio none\npages 2"))
    }

    @Test("a PDF of one page is that page, and one of more pages with no page named gives only its page count")
    func writesPageCount() throws {
        // Given
        let facts = MediaFactTable(
            files: [:],
            pages: [
                "/abs/logo.pdf": [Size(width: 64, height: 32)],
                "/abs/deck.pdf": [Size(width: 10, height: 10), Size(width: 20, height: 20)]
            ]
        )
        let sut = ProbeReporter(mediaFacts: facts)

        // When
        let one = try sut.report(of: "/abs/logo.pdf")
        let several = try sut.report(of: "/abs/deck.pdf")

        // Then
        #expect(one.kind == "page" && one.size == Size(width: 64, height: 32) && one.pageCount == 1)
        let expected = #"""
            {"probe": "1.0.0", "kind": null, "size": null, "duration": null, "fps": null, "alpha": null, \#
            "colorSpace": null, "audio": null, "pages": 2}
            """#
        #expect(several.machineOutput.written == expected)
    }

    @Test("pages is null for media that is no PDF, and a page above the count or of a file that is no PDF stops")
    func refusesMissingPage() throws {
        // Given
        let facts = MediaFactTable(
            files: ["/abs/card.png": ProbedMedia(kind: .image, size: Size(width: 8, height: 8))],
            pages: ["/abs/deck.pdf": [Size(width: 10, height: 10), Size(width: 20, height: 20)]]
        )
        let sut = ProbeReporter(mediaFacts: facts)

        // When
        let image = try sut.report(of: "/abs/card.png").machineOutput.objectValue
        let above = #expect(throws: AnalysisError.self) { try sut.report(of: "/abs/deck.pdf", page: 3) }
        let notPDF = #expect(throws: AnalysisError.self) { try sut.report(of: "/abs/card.png", page: 1) }
        let missing = #expect(throws: AnalysisError.self) { try sut.report(of: "/abs/absent.pdf", page: 1) }

        // Then
        #expect(image?["pages"] == .null)
        #expect(above?.description == #"--page: media "/abs/deck.pdf" has 2 pages, so it has no page 3"#)
        #expect(notPDF?.description == #"--page: media "/abs/card.png" is not a PDF, so it has no page 1"#)
        #expect(missing?.description == #"media "/abs/absent.pdf" is not there"#)
    }

    @Test("the text gives one fact a line, none where the medium has none")
    func writesText() throws {
        // Given
        let path = "/abs/run.mp4"

        // When
        let report = try sut.report(of: path)

        // Then
        #expect(report.text.split(separator: "\n") == [
            "kind video",
            "size 1080x1920",
            "duration 30",
            "fps 29.97",
            "alpha no",
            "color space none",
            "audio 2 channels, 48000 Hz",
            "pages none"
        ])
        #expect(try sut.report(of: "/abs/card.png").text.contains("duration none\nfps none\nalpha no\ncolor space"))
    }

    @Test("media that is not there stops, and one the decoder cannot read stops with its reason")
    func refusesMissingAndUnreadableMedia() {
        // Given
        let failure = ProbeFailure("media /abs/notes.txt cannot be read")
        let facts = MediaFactTable(files: [:], failures: ["/abs/notes.txt": failure])
        let sut = ProbeReporter(mediaFacts: facts)

        // When
        let missing = #expect(throws: AnalysisError.self) { try sut.report(of: "/abs/absent.mov") }
        let unreadable = #expect(throws: ProbeFailure.self) { try sut.report(of: "/abs/notes.txt") }

        // Then
        #expect(missing?.description == #"media "/abs/absent.mov" is not there"#)
        #expect(unreadable?.description == "media /abs/notes.txt cannot be read")
    }

    @Test("a real video, still and image sequence are probed through the decoder with their alpha, colour and sound")
    func probesRealMedia() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let video = directory.file("clip.mov")
        let still = directory.file("card.png")
        let sequence = directory.file("frames")
        let size = Size(width: 64, height: 48)
        try await MovieWriter(size: size, frameTimes: [0, 0.5], end: 1, sound: true).write(to: video) { canvas, _ in
            canvas.fill(red: 128, green: 128, blue: 128)
        }
        try ImageWriter(size: size).write(to: still) { _ in }
        try FileManager.default.createDirectory(atPath: sequence, withIntermediateDirectories: false)
        for name in ["1.png", "2.png"] {
            let frame = (sequence as NSString).appendingPathComponent(name)
            try ImageWriter(size: size, opaque: true).write(to: frame) { _ in }
        }
        let sut = ProbeReporter(mediaFacts: AVFoundationDecoder())
        let taggedSRGB = ProbedColorSpace(
            reading: .formulas(.srgb),
            primaries: 1,
            transfer: 13,
            matrix: nil,
            bitDepth: 8,
            isHighDynamicRange: false
        )

        // When
        let videoReport = try sut.report(of: video)
        let stillReport = try sut.report(of: still)
        let sequenceReport = try sut.report(of: sequence)

        // Then
        #expect(videoReport == ProbeReport(
            kind: "video",
            size: size,
            duration: 1,
            fps: 2,
            hasAlpha: false,
            colorSpace: ProbedColorSpace(
                reading: .formulas(.srgb),
                primaries: 1,
                transfer: 13,
                matrix: 1,
                bitDepth: 8,
                isHighDynamicRange: false
            ),
            sound: ProbedSound(channels: 1, sampleRate: 48_000)
        ))
        #expect(stillReport == ProbeReport(
            kind: "image",
            size: size,
            duration: nil,
            fps: nil,
            hasAlpha: true,
            colorSpace: taggedSRGB,
            sound: nil
        ))
        #expect(sequenceReport == ProbeReport(
            kind: "imageSequence",
            size: size,
            duration: nil,
            fps: nil,
            hasAlpha: false,
            colorSpace: taggedSRGB,
            sound: nil
        ))
    }

    // MARK: - Private
}

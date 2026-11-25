//
//  OCRReporterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesAVFoundation
import FramesTestMedia
import FramesVision
import Testing

@testable import Frames

// Serialized, so that the tests running at once read far fewer files with AVFoundation than the 64 at once at which its
// reads stop finishing (FRAMES-21 Notes).
@Suite("OCRReporter Tests", .serialized, .ownThread)
struct OCRReporterTests {
    // MARK: - Property
    // `/abs/clip.mov` has four frames a second for a second. Its OCR finds "Second" from media second 0.5 on.
    private let facts = MediaFactTable(files: [
        "/abs/clip.mov": ProbedMedia(
            kind: .video,
            duration: 1,
            fps: 4,
            frames: [0, 0.25, 0.5, 0.75],
            size: Size(width: 400, height: 300)
        ),
        "/abs/card.png": ProbedMedia(kind: .image, size: Size(width: 400, height: 300)),
        "/abs/logo.pdf": ProbedMedia(kind: .page, size: Size(width: 200, height: 100)),
        "/abs/ding.wav": ProbedMedia(kind: .audio, duration: 1, sound: ProbedSound(channels: 1, sampleRate: 48_000))
    ])
    private let first = RecognisedLine(text: "First", rectangle: Rectangle(x: 10, y: 20, width: 100, height: 30))
    private let second = RecognisedLine(text: "Second", rectangle: Rectangle(x: 10, y: 100, width: 120.4, height: 30))
    private var ocr: OCRTable {
        OCRTable([
            "/abs/clip.mov": [(from: 0, lines: [first]), (from: 0.5, lines: [second, first])],
            "/abs/card.png": [(from: 0, lines: [first])]
        ])
    }

    // MARK: - Initializer
    // MARK: - Test
    @Test("the machine output is the ocr object FRAMES-23 gives, an image's one frame at time 0")
    func writesMachineOutput() throws {
        // Given
        let sut = OCRReporter(mediaFacts: facts, ocr: ocr, languages: nil)

        // When
        let report = try sut.report(of: "/abs/card.png")

        // Then
        let expected = #"""
            {"ocr": "0.1.0", "size": [400, 300], "languages": null, "frames": [{"time": 0, "lines": [\#
            {"text": "First", "rect": [10, 20, 100, 30]}]}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("the machine output writes a line's rectangle to the nearest millionth, without Vision's noise")
    func roundsRectangles() throws {
        // Given
        let noisy = RecognisedLine(
            text: "Send",
            rectangle: Rectangle(x: 93.99999999268294, y: 187.99999997439016, width: 128, height: 42.000000000000014)
        )
        let sut = OCRReporter(mediaFacts: facts, ocr: OCRTable(file: "/abs/card.png", lines: [noisy]), languages: nil)

        // When
        let report = try sut.report(of: "/abs/card.png")

        // Then
        let expected = #"""
            {"ocr": "0.1.0", "size": [400, 300], "languages": null, "frames": [{"time": 0, "lines": [\#
            {"text": "Send", "rect": [94, 188, 128, 42]}]}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("a page is read as a still of its size in points, the page named or the one page of a PDF of one page")
    func readsPage() throws {
        // Given
        let facts = MediaFactTable(
            files: [:],
            pages: [
                "/abs/deck.pdf": [Size(width: 100, height: 50), Size(width: 595.2756, height: 841.8898)],
                "/abs/logo.pdf": [Size(width: 64, height: 32)]
            ]
        )
        let ocr = OCRTable([
            "/abs/deck.pdf#2": [(from: 0, lines: [second])],
            "/abs/logo.pdf#1": [(from: 0, lines: [first])]
        ])
        let sut = OCRReporter(mediaFacts: facts, ocr: ocr, languages: nil)

        // When
        let page = try sut.report(of: "/abs/deck.pdf", page: 2)
        let onePage = try sut.report(of: "/abs/logo.pdf")
        let unnamed = #expect(throws: AnalysisError.self) { try sut.report(of: "/abs/deck.pdf") }
        let timed = #expect(throws: AnalysisError.self) { try sut.report(of: "/abs/logo.pdf", at: .at(1)) }

        // Then
        let expected = #"""
            {"ocr": "0.1.0", "size": [595.2756, 841.8898], "languages": null, "frames": [{"time": 0, "lines": [\#
            {"text": "Second", "rect": [10, 100, 120.4, 30]}]}]}
            """#
        #expect(page.machineOutput.written == expected)
        #expect(onePage.frames == [OCRFrame(time: 0, lines: [first])])
        #expect(unnamed?.description == #"""
            media "/abs/deck.pdf" is a PDF of 2 pages, more than one picture, so --page names the page
            """#)
        #expect(timed == .timeOnStill(file: "/abs/logo.pdf"))
    }

    @Test("lines come in reading order, top to bottom by row and left to right within a row")
    func ordersLines() throws {
        // Given
        let right = RecognisedLine(text: "Right", rectangle: Rectangle(x: 200, y: 22, width: 50, height: 30))
        let below = RecognisedLine(text: "Below", rectangle: Rectangle(x: 0, y: 200, width: 50, height: 30))
        let sut = OCRReporter(mediaFacts: facts, ocr: OCRTable(file: "/abs/card.png", lines: [below, right, first]), languages: nil)

        // When
        let report = try sut.report(of: "/abs/card.png")

        // Then
        #expect(report.frames.map { $0.lines.map(\.text) } == [["First", "Right", "Below"]])
    }

    @Test("a video is read at the start with no time, at `--at`, or at each step of a range", arguments: [
        (TimeSelection.start, [0.0]),
        (.at(0.6), [0.6]),
        (.range(FrameRange(from: nil, to: nil, step: 0.25)), [0, 0.25, 0.5, 0.75]),
        (.range(FrameRange(from: 0.25, to: 0.75, step: 0.2)), [0.25, 0.45, 0.65]),
        (.range(FrameRange(from: 0, to: 0.3, step: 0.1)), [0, 0.1, 0.2])
    ])
    func readsTimes(selection: TimeSelection, times: [Double]) throws {
        // Given
        let sut = OCRReporter(mediaFacts: facts, ocr: ocr, languages: nil)

        // When
        let report = try sut.report(of: "/abs/clip.mov", at: selection)

        // Then
        #expect(report.frames.map(\.time) == times)
        #expect(report.frames.map { $0.lines.count } == times.map { $0 < 0.5 ? 1 : 2 })
    }

    @Test("the text gives the size, then each line, and each frame of a range under its media time")
    func writesText() throws {
        // Given
        let sut = OCRReporter(mediaFacts: facts, ocr: ocr, languages: nil)

        // When
        let single = try sut.report(of: "/abs/clip.mov", at: .at(0.5))
        let range = try sut.report(of: "/abs/clip.mov", at: .range(FrameRange(from: 0.25, to: nil, step: 0.5)))

        // Then
        #expect(single.text.split(separator: "\n") == [
            "size 400x300",
            "[10, 20, 100, 30]  First",
            "[10, 100, 120, 30]  Second"
        ])
        #expect(range.text.split(separator: "\n") == [
            "size 400x300",
            "time 0.25",
            "[10, 20, 100, 30]  First",
            "time 0.75",
            "[10, 20, 100, 30]  First",
            "[10, 100, 120, 30]  Second"
        ])
    }

    @Test(
        "times outside the media, an empty range, a zero step and a time on an image stop, naming the option",
        arguments: [
            ("/abs/clip.mov", TimeSelection.at(1), #"--at: media second 1 is at or after the end of "/abs/clip.mov" at 1"#),
            ("/abs/clip.mov", .at(-0.5), #"--at: media second -0.5 is before the start of "/abs/clip.mov""#),
            (
                "/abs/clip.mov",
                .range(FrameRange(from: nil, to: 2, step: 1)),
                #"--to: media second 2 is after the end of "/abs/clip.mov" at 1"#
            ),
            ("/abs/clip.mov", .range(FrameRange(from: 0.5, to: 0.5, step: 0.1)), "--from: 0.5 is not before --to 0.5"),
            (
                "/abs/clip.mov",
                .range(FrameRange(from: nil, to: nil, step: 0)),
                "--step: the step must be at least a microsecond, found 0"
            ),
            (
                "/abs/card.png",
                .at(0),
                #"media "/abs/card.png" is a still, whose one picture is at time 0, so it takes neither --at nor a range"#
            ),
            (
                "/abs/logo.pdf",
                .range(FrameRange(from: nil, to: nil, step: 1)),
                #"media "/abs/logo.pdf" is a still, whose one picture is at time 0, so it takes neither --at nor a range"#
            ),
            ("/abs/ding.wav", .start, #"media "/abs/ding.wav" is sound, so it has no picture to read"#),
            ("/abs/absent.mov", .start, #"media "/abs/absent.mov" is not there"#)
        ]
    )
    func refusesBadTimes(file: String, selection: TimeSelection, message: String) {
        // Given
        let sut = OCRReporter(mediaFacts: facts, ocr: ocr, languages: nil)

        // When
        let error = #expect(throws: AnalysisError.self) { try sut.report(of: file, at: selection) }

        // Then
        #expect(error?.description == message)
    }

    @Test("a real still and a real video frame are read through the decoder and Vision, in media pixels")
    func recognisesRealMedia() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let still = directory.file("card.png")
        let video = directory.file("screen.mov")
        var drawn = Rectangle(x: 0, y: 0, width: 0, height: 0)
        try ImageWriter(size: Size(width: 720, height: 400)).write(to: still) { canvas in
            canvas.fill(red: 255, green: 255, blue: 255)
            drawn = canvas.draw("Send message", font: "Helvetica", size: 48, x: 60, y: 200)
        }
        let recording = ScreenRecording(scale: 0.5)
        let scrolled = try await recording.write(to: video)
        let decoder = AVFoundationDecoder()
        let sut = OCRReporter(mediaFacts: decoder, ocr: VisionOCR(decoder: decoder), languages: nil)

        // When
        let stillReport = try sut.report(of: still)
        let videoReport = try sut.report(of: video, at: .at(0.5))

        // Then
        #expect(stillReport.size == Size(width: 720, height: 400))
        #expect(stillReport.frames.map { $0.lines.map(\.text) } == [["Send message"]])
        #expect(stillReport.frames.first?.lines.first.map { isNear($0.rectangle, drawn) } == true)
        let lines = try #require(videoReport.frames.first?.lines)
        let total = try #require(lines.last)
        #expect(videoReport.size == recording.size)
        #expect(lines.count == 2 && lines.first?.text == "Send message" && total.text.hasPrefix("Total"))
        #expect(isNear(total.rectangle, scrolled[15]), "\(total) drawn at \(scrolled[15])")
    }

    @Test("a failing provider stops, naming the option that chose the frame, the media and its media time", arguments: [
        ("/abs/card.png", TimeSelection.start, #"ocr: the OCR provider failed on "/abs/card.png" at media second 0: no model"#),
        ("/abs/clip.mov", TimeSelection.at(0.5), #"--at: the OCR provider failed on "/abs/clip.mov" at media second 0.5: no model"#),
        (
            "/abs/clip.mov",
            TimeSelection.range(FrameRange(from: 0.25, to: 0.75, step: 0.25)),
            #"--from: the OCR provider failed on "/abs/clip.mov" at media second 0.25: no model"#
        )
    ])
    func namesFailingProvider(
        file: String,
        selection: TimeSelection,
        message: String
    ) {
        // Given
        let sut = OCRReporter(mediaFacts: facts, ocr: FailingOCR(ProviderFailure("no model")), languages: nil)

        // When
        let error = #expect(throws: ProviderError.self) { try sut.report(of: file, at: selection) }

        // Then
        #expect(error?.description == message)
    }

    // MARK: - Private
    // Within 8 pixels of the drawn line box on every edge.
    private func isNear(
        _ rectangle: Rectangle,
        _ drawn: Rectangle
    ) -> Bool {
        let edges = [
            rectangle.x - drawn.x,
            rectangle.y - drawn.y,
            rectangle.x + rectangle.width - drawn.x - drawn.width,
            rectangle.y + rectangle.height - drawn.y - drawn.height
        ]

        return edges.allSatisfy { abs($0) <= 8 }
    }
}

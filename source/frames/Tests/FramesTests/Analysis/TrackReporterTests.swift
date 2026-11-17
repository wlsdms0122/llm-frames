//
//  TrackReporterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesAVFoundation
import FramesPointTracker
import FramesTestMedia
import FramesVision
import Testing

@testable import Frames

// Serialized, since AVAssetReader needs a free thread of the shared pool, which tests reading video at once can
// all hold.
@Suite("TrackReporter Tests", .serialized)
struct TrackReporterTests {
    // MARK: - Property
    // `/abs/clip.mov` has four frames a second for a second, and its target moves up 40 pixels a second wherever it
    // is followed.
    private let times = [0, 0.25, 0.5, 0.75]
    private let facts = MediaFactTable(files: [
        "/abs/clip.mov": ProbedMedia(
            kind: .video,
            duration: 1,
            fps: 4,
            frames: [0, 0.25, 0.5, 0.75],
            size: Size(width: 400, height: 300)
        ),
        "/abs/card.png": ProbedMedia(kind: .image, size: Size(width: 400, height: 300))
    ])
    private let total = Rectangle(x: 100, y: 100, width: 200, height: 40)
    private let sends = [
        Rectangle(x: 20, y: 200, width: 80, height: 30),
        Rectangle(x: 220, y: 200, width: 80, height: 30)
    ]
    private var ocr: OCRTable {
        OCRTable(file: "/abs/clip.mov", lines: [
            RecognisedLine(text: "Total", rectangle: total),
            RecognisedLine(text: "Send", rectangle: sends[1]),
            RecognisedLine(text: "Send", rectangle: sends[0])
        ])
    }
    private var tracker: TrackerTable {
        TrackerTable(frameTimes: ["/abs/clip.mov": times], drift: Point(x: 0, y: -40))
    }

    // MARK: - Initializer
    // MARK: - Test
    @Test("the machine output is the track object FRAMES-23 gives, a rectangle followed over the whole video")
    func writesMachineOutput() throws {
        // Given
        let sut = TrackReporter(mediaFacts: facts, ocr: OCRTable([:]), tracker: tracker)

        // When
        let report = try sut.report(of: "/abs/clip.mov", area: "[10, 20, 100, 50]", at: 0.25)

        // Then
        let expected = #"""
            {"track": "1.0.0", "frames": [{"time": 0, "rect": [10, 30, 100, 50]}, \#
            {"time": 0.25, "rect": [10, 20, 100, 50]}, {"time": 0.5, "rect": [10, 10, 100, 50]}, \#
            {"time": 0.75, "rect": [10, 0, 100, 50]}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("the machine output writes each rectangle to the nearest millionth, without the tracker's noise")
    func roundsRectangles() throws {
        // Given
        let noisy = Rectangle(x: 93.99999999268294, y: 99.99999997439016, width: 200.00000000000003, height: 42)
        let sut = TrackReporter(
            mediaFacts: facts,
            ocr: OCRTable([:]),
            tracker: TrackerTable(frameTimes: ["/abs/clip.mov": [0, 0.25]])
        )

        // When
        let report = try sut.report(
            of: "/abs/clip.mov",
            area: "[\(noisy.x), \(noisy.y), \(noisy.width), \(noisy.height)]",
            at: 0
        )

        // Then
        let expected = #"""
            {"track": "1.0.0", "frames": [{"time": 0, "rect": [94, 100, 200, 42]}, \#
            {"time": 0.25, "rect": [94, 100, 200, 42]}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test(
        "a text area is found by OCR at `--at` and followed before padding",
        arguments: [(#"{"text": "Total"}"#, 0), (#"{"text": "Total", "padding": 20}"#, 0), (#"{"text": "Send", "nth": 1}"#, 2)]
    )
    func followsFoundArea(area: String, line: Int) throws {
        // Given
        let sut = TrackReporter(mediaFacts: facts, ocr: ocr, tracker: tracker)
        let found = [total, sends[0], sends[1]][line]

        // When
        let report = try sut.report(of: "/abs/clip.mov", area: area, at: 0.5)

        // Then
        #expect(report.frames.map(\.time) == times)
        #expect(report.frames.first(where: { $0.time == 0.5 })?.rectangle == found)
    }

    @Test("with `--to` only the frames shown between it and `--at` are followed, either way", arguments: [
        (0.25, 0.5, [0.25, 0.5]),
        (0.25, 0.6, [0.25, 0.5]),
        (0.5, 0, [0, 0.25, 0.5]),
        (0.5, 0.1, [0, 0.25, 0.5])
    ])
    func followsToTime(at: Double, to: Double, followed: [Double]) throws {
        // Given
        let sut = TrackReporter(mediaFacts: facts, ocr: ocr, tracker: tracker)

        // When
        let report = try sut.report(of: "/abs/clip.mov", area: #"{"text": "Total"}"#, at: at, to: to)

        // Then
        #expect(report.frames.map(\.time) == followed)
    }

    @Test("a bad or unmatched area stops, naming `--area`, and so do an image and times outside the video", arguments: [
        ("/abs/clip.mov", "Total", 0.5, nil, "--area: line 1, column 1: "),
        ("/abs/clip.mov", #"{"text": "Total", "nht": 1}"#, 0.5, nil, #"--area (text area): unknown key "nht". "#),
        ("/abs/clip.mov", #""Total""#, 0.5, nil, #"--area (area): expected an area, found "Total""#),
        ("/abs/clip.mov", #"{"band": {"text": "Total"}}"#, 0.5, nil, "--area (area): needs one of text, from"),
        ("/abs/clip.mov", #"{"text": "Missing"}"#, 0.5, nil, #"--area (area): no line of "/abs/clip.mov" at media second 0.5 "#),
        ("/abs/clip.mov", #"{"text": "Send"}"#, 0.5, nil, #"--area (area): "Send" matches 2 lines: [20, 200, 80, 30] "Send""#),
        ("/abs/card.png", #"{"text": "Total"}"#, 0, nil, #"media "/abs/card.png" is an image, and only a video has frames"#),
        ("/abs/clip.mov", #"{"text": "Total"}"#, 1, nil, #"--at: media second 1 is at or after the end of "/abs/clip.mov" at 1"#),
        ("/abs/clip.mov", #"{"text": "Total"}"#, 0.5, 1.5, #"--to: media second 1.5 is after the end of "/abs/clip.mov" at 1"#),
        ("/abs/absent.mov", #"{"text": "Total"}"#, 0, nil, #"media "/abs/absent.mov" is not there"#)
    ] as [(String, String, Double, Double?, String)])
    func refusesBadArguments(
        file: String,
        area: String,
        at: Double,
        to: Double?,
        message: String
    ) {
        // Given
        let sut = TrackReporter(mediaFacts: facts, ocr: ocr, tracker: tracker)

        // When
        let error = #expect(throws: (any Error).self) { try sut.report(of: file, area: area, at: at, to: to) }

        // Then
        let description = error.map { String(describing: $0) } ?? ""
        #expect(description.hasPrefix(message), "\(description)")
    }

    @Test("a real scrolling line is found by Vision and followed by the point tracker over every frame")
    func followsRealLine() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let video = directory.file("screen.mov")
        let drawn = try await ScreenRecording(scale: 0.5).write(to: video)
        let decoder = AVFoundationDecoder()
        let sut = TrackReporter(
            mediaFacts: decoder,
            ocr: VisionOCR(decoder: decoder),
            tracker: PointTracker(decoder: decoder)
        )

        // When
        let report = try sut.report(of: video, area: #"{"text": "Total"}"#, at: 0.5)

        // Then
        #expect(report.frames.map(\.time) == ScreenRecording.frameTimes)
        let start = try #require(report.frames.first { $0.time == 0.5 })
        for (index, frame) in report.frames.enumerated() {
            let moved = frame.rectangle.center.y - start.rectangle.center.y
            let drift = drawn[index].center.y - drawn[15].center.y
            #expect(abs(moved - drift) <= 1.5, "frame \(index) moved \(moved), drawn \(drift)")
            #expect(abs(frame.rectangle.center.x - start.rectangle.center.x) <= 1.5, "frame \(index) moved along")
        }
    }

    // MARK: - Private
}

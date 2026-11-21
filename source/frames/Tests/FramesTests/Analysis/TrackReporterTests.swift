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
    ], pages: ["/abs/deck.pdf": [Size(width: 612, height: 792)]])
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
        let sut = TrackReporter(mediaFacts: facts, ocr: OCRTable([:]), languages: nil, tracker: tracker)

        // When
        let report = try sut.report(of: "/abs/clip.mov", area: "[10, 20, 100, 50]", at: 0.25)

        // Then
        let expected = #"""
            {"track": "1.0.0", "time": 0.25, "target": [[10, 20], [110, 20], [110, 70], [10, 70]], "frames": [\#
            {"time": 0, "quad": [[10, 30], [110, 30], [110, 80], [10, 80]], "motion": [1, 0, 0, 1, 0, 10]}, \#
            {"time": 0.25, "quad": [[10, 20], [110, 20], [110, 70], [10, 70]], "motion": [1, 0, 0, 1, 0, 0]}, \#
            {"time": 0.5, "quad": [[10, 10], [110, 10], [110, 60], [10, 60]], "motion": [1, 0, 0, 1, 0, -10]}, \#
            {"time": 0.75, "quad": [[10, 0], [110, 0], [110, 50], [10, 50]], "motion": [1, 0, 0, 1, 0, -20]}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("a target turning a quarter turn clockwise reports its quad turned and the motion's matrix of that turn")
    func writesQuarterTurn() throws {
        // Given
        let sut = TrackReporter(
            mediaFacts: facts,
            ocr: OCRTable([:]),
            languages: nil,
            tracker: TrackerTable(frameTimes: ["/abs/clip.mov": [0, 0.25]], turn: 360)
        )

        // When
        let report = try sut.report(of: "/abs/clip.mov", area: "[0, 0, 100, 50]", at: 0)

        // Then
        let expected = #"""
            {"track": "1.0.0", "time": 0, "target": [[0, 0], [100, 0], [100, 50], [0, 50]], "frames": [\#
            {"time": 0, "quad": [[0, 0], [100, 0], [100, 50], [0, 50]], "motion": [1, 0, 0, 1, 0, 0]}, \#
            {"time": 0.25, "quad": [[75, -25], [75, 75], [25, 75], [25, -25]], "motion": [0, 1, -1, 0, 75, -25]}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("the machine output writes each corner to the nearest millionth, without the tracker's noise")
    func roundsQuads() throws {
        // Given
        let noisy = Rectangle(x: 93.99999999268294, y: 99.99999997439016, width: 200.00000000000003, height: 42)
        let sut = TrackReporter(
            mediaFacts: facts,
            ocr: OCRTable([:]),
            languages: nil,
            tracker: TrackerTable(frameTimes: ["/abs/clip.mov": [0]])
        )

        // When
        let report = try sut.report(
            of: "/abs/clip.mov",
            area: "[\(noisy.x), \(noisy.y), \(noisy.width), \(noisy.height)]",
            at: 0,
            to: 0
        )

        // Then
        let expected = #"""
            {"track": "1.0.0", "time": 0, "target": [[94, 100], [294, 100], [294, 142], [94, 142]], "frames": [\#
            {"time": 0, "quad": [[94, 100], [294, 100], [294, 142], [94, 142]], "motion": [1, 0, 0, 1, 0, 0]}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test(
        "a text area is found by OCR at `--at` and followed before padding",
        arguments: [(#"{"text": "Total"}"#, 0), (#"{"text": "Total", "padding": 20}"#, 0), (#"{"text": "Send", "nth": 1}"#, 2)]
    )
    func followsFoundArea(area: String, line: Int) throws {
        // Given
        let sut = TrackReporter(mediaFacts: facts, ocr: ocr, languages: nil, tracker: tracker)
        let found = [total, sends[0], sends[1]][line]

        // When
        let report = try sut.report(of: "/abs/clip.mov", area: area, at: 0.5)

        // Then
        #expect(report.track.samples.map(\.time) == times)
        #expect(report.track.target == Quad(found))
        #expect(report.track.samples.first(where: { $0.time == 0.5 })?.quad == Quad(found))
    }

    @Test("with `--to` only the frames shown between it and `--at` are followed, either way", arguments: [
        (0.25, 0.5, [0.25, 0.5]),
        (0.25, 0.6, [0.25, 0.5]),
        (0.5, 0, [0, 0.25, 0.5]),
        (0.5, 0.1, [0, 0.25, 0.5])
    ])
    func followsToTime(at: Double, to: Double, followed: [Double]) throws {
        // Given
        let sut = TrackReporter(mediaFacts: facts, ocr: ocr, languages: nil, tracker: tracker)

        // When
        let report = try sut.report(of: "/abs/clip.mov", area: #"{"text": "Total"}"#, at: at, to: to)

        // Then
        #expect(report.track.samples.map(\.time) == followed)
    }

    @Test("a bad or unmatched area stops, naming `--area`, and so do an image, a page and times outside the video", arguments: [
        ("/abs/clip.mov", "Total", 0.5, nil, "--area: line 1, column 1: "),
        ("/abs/clip.mov", #"{"text": "Total", "nht": 1}"#, 0.5, nil, #"--area (text area): unknown key "nht". "#),
        ("/abs/clip.mov", #""Total""#, 0.5, nil, #"--area (area): expected an area, found "Total""#),
        ("/abs/clip.mov", #"{"band": {"text": "Total"}}"#, 0.5, nil, "--area (area): needs one of text, from, clip"),
        ("/abs/clip.mov", #"{"text": "Missing"}"#, 0.5, nil, #"--area (area): no line of "/abs/clip.mov" at media second 0.5 "#),
        ("/abs/clip.mov", #"{"text": "Send"}"#, 0.5, nil, #"--area (area): "Send" matches 2 lines: [20, 200, 80, 30] "Send""#),
        ("/abs/card.png", #"{"text": "Total"}"#, 0, nil, #"media "/abs/card.png" is a still, and only a video has frames"#),
        ("/abs/deck.pdf", #"{"text": "Total"}"#, 0, nil, #"media "/abs/deck.pdf" is a still, and only a video has frames"#),
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
        let sut = TrackReporter(mediaFacts: facts, ocr: ocr, languages: nil, tracker: tracker)

        // When
        let error = #expect(throws: (any Error).self) { try sut.report(of: file, area: area, at: at, to: to) }

        // Then
        let description = error.map { String(describing: $0) } ?? ""
        #expect(description.hasPrefix(message), "\(description)")
    }

    @Test("a failing tracker or OCR provider stops, naming `--area`, the video and the media time of `--at`")
    func namesFailingProvider() {
        // Given
        let failure = ProviderFailure("no model")
        let failingTracker = TrackReporter(mediaFacts: facts, ocr: ocr, languages: nil, tracker: FailingTracker(failure))
        let failingOCR = TrackReporter(mediaFacts: facts, ocr: FailingOCR(failure), languages: nil, tracker: tracker)

        // When
        let trackerError = #expect(throws: ProviderError.self) {
            try failingTracker.report(of: "/abs/clip.mov", area: #"{"text": "Total"}"#, at: 0.5)
        }
        let ocrError = #expect(throws: ProviderError.self) {
            try failingOCR.report(of: "/abs/clip.mov", area: #"{"text": "Total"}"#, at: 0.5)
        }

        // Then
        #expect(
            trackerError?.description
                == #"--area (area): the tracker failed on "/abs/clip.mov" at media second 0.5: no model"#
        )
        #expect(
            ocrError?.description
                == #"--area (area): the OCR provider failed on "/abs/clip.mov" at media second 0.5: no model"#
        )
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
            languages: nil,
            tracker: PointTracker(decoder: decoder)
        )

        // When
        let report = try sut.report(of: video, area: #"{"text": "Total"}"#, at: 0.5)

        // Then
        #expect(report.track.samples.map(\.time) == ScreenRecording.frameTimes)
        let start = try #require(report.track.samples.first { $0.time == 0.5 })
        for (index, frame) in report.track.samples.enumerated() {
            let moved = frame.quad.centroid.y - start.quad.centroid.y
            let drift = drawn[index].center.y - drawn[15].center.y
            #expect(abs(moved - drift) <= 1.5, "frame \(index) moved \(moved), drawn \(drift)")
            #expect(abs(frame.quad.centroid.x - start.quad.centroid.x) <= 1.5, "frame \(index) moved along")
        }
    }

    // MARK: - Private
}

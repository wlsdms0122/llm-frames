//
//  TrackReporterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesAVFoundation
import FramesTestMedia
import FramesTracker
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
    private var tracker: TrackerTable {
        TrackerTable(frameTimes: ["/abs/clip.mov": times], drift: Point(x: 0, y: -40))
    }

    // MARK: - Initializer
    // MARK: - Test
    @Test("the machine output is the track object FRAMES-23 gives, a rectangle followed over the whole video")
    func writesMachineOutput() throws {
        // Given
        let sut = TrackReporter(mediaFacts: facts, tracker: tracker)

        // When
        let report = try sut.report(of: "/abs/clip.mov", target: .area("[10, 20, 100, 50]"), at: 0.25)

        // Then
        let expected = #"""
            {"track": "0.1.0", "time": 0.25, "frames": [\#
            {"time": 0, "quad": [[10, 30], [110, 30], [110, 80], [10, 80]]}, \#
            {"time": 0.25, "quad": [[10, 20], [110, 20], [110, 70], [10, 70]]}, \#
            {"time": 0.5, "quad": [[10, 10], [110, 10], [110, 60], [10, 60]]}, \#
            {"time": 0.75, "quad": [[10, 0], [110, 0], [110, 50], [10, 50]]}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("a target turning a quarter turn clockwise reports its quad turned a quarter turn on the next frame")
    func writesQuarterTurn() throws {
        // Given
        let sut = TrackReporter(
            mediaFacts: facts,
            tracker: TrackerTable(frameTimes: ["/abs/clip.mov": [0, 0.25]], turn: 360)
        )

        // When
        let report = try sut.report(of: "/abs/clip.mov", target: .area("[0, 0, 100, 50]"), at: 0)

        // Then
        let expected = #"""
            {"track": "0.1.0", "time": 0, "frames": [\#
            {"time": 0, "quad": [[0, 0], [100, 0], [100, 50], [0, 50]]}, \#
            {"time": 0.25, "quad": [[75, -25], [75, 75], [25, 75], [25, -25]]}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("the machine output writes each corner to the nearest millionth, without the tracker's noise")
    func roundsQuads() throws {
        // Given
        let noisy = Rectangle(x: 93.99999999268294, y: 99.99999997439016, width: 200.00000000000003, height: 42)
        let sut = TrackReporter(
            mediaFacts: facts,
            tracker: TrackerTable(frameTimes: ["/abs/clip.mov": [0]])
        )

        // When
        let report = try sut.report(
            of: "/abs/clip.mov",
            target: .area("[\(noisy.x), \(noisy.y), \(noisy.width), \(noisy.height)]"),
            at: 0,
            to: 0
        )

        // Then
        let expected = #"""
            {"track": "0.1.0", "time": 0, "frames": [\#
            {"time": 0, "quad": [[94, 100], [294, 100], [294, 142], [94, 142]]}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("with `--to` only the frames shown between it and `--at` are followed, either way", arguments: [
        (0.25, 0.5, [0.25, 0.5]),
        (0.25, 0.6, [0.25, 0.5]),
        (0.5, 0, [0, 0.25, 0.5]),
        (0.5, 0.1, [0, 0.25, 0.5])
    ])
    func followsToTime(at: Double, to: Double, followed: [Double]) throws {
        // Given
        let sut = TrackReporter(mediaFacts: facts, tracker: tracker)

        // When
        let report = try sut.report(of: "/abs/clip.mov", target: .area("[100, 100, 200, 40]"), at: at, to: to)

        // Then
        #expect(report.frames.map(\.time) == followed)
    }

    @Test("a bad area or a clip area stops, naming `--area`, and so do an image, a page and times outside the video", arguments: [
        ("/abs/clip.mov", "Total", 0.5, nil, "--area: line 1, column 1: "),
        ("/abs/clip.mov", #"{"clip": "card", "nht": 1}"#, 0.5, nil, #"--area (clip area): unknown key "nht". "#),
        ("/abs/clip.mov", #""Total""#, 0.5, nil, #"--area (area): expected an area, found "Total""#),
        ("/abs/clip.mov", #"{"padding": 4}"#, 0.5, nil, #"--area (clip area): missing key "clip""#),
        ("/abs/clip.mov", #"{"clip": "card"}"#, 0.5, nil, "--area (area): a clip area is the box of another clip"),
        ("/abs/card.png", "[100, 100, 200, 40]", 0, nil, #"media "/abs/card.png" is a still, and only a video or an image sequence has frames"#),
        ("/abs/deck.pdf", "[100, 100, 200, 40]", 0, nil, #"media "/abs/deck.pdf" is a still, and only a video or an image sequence has frames"#),
        ("/abs/clip.mov", "[100, 100, 200, 40]", 1, nil, #"--at: media second 1 is at or after the end of "/abs/clip.mov" at 1"#),
        ("/abs/clip.mov", "[100, 100, 200, 40]", 0.5, 1.5, #"--to: media second 1.5 is after the end of "/abs/clip.mov" at 1"#),
        ("/abs/absent.mov", "[100, 100, 200, 40]", 0, nil, #"media "/abs/absent.mov" is not there"#)
    ] as [(String, String, Double, Double?, String)])
    func refusesBadArguments(
        file: String,
        area: String,
        at: Double,
        to: Double?,
        message: String
    ) {
        // Given
        let sut = TrackReporter(mediaFacts: facts, tracker: tracker)

        // When
        let error = #expect(throws: (any Error).self) { try sut.report(of: file, target: .area(area), at: at, to: to) }

        // Then
        let description = error.map { String(describing: $0) } ?? ""
        #expect(description.hasPrefix(message), "\(description)")
    }

    @Test("an area the tracker follows on no frame stops, naming the video and the media time of `--at`", arguments: [
        ("[500, 400, 50, 50]", [0, 0.75]),
        ("[100, 100, 200, 40]", [0.75, 0.75])
    ] as [(String, [Double])])
    func refusesAreaNotFollowed(area: String, followed: [Double]) {
        // Given
        let tracker = TrackerTable(frameTimes: ["/abs/clip.mov": times], followed: ["/abs/clip.mov": followed[0]...followed[1]])
        let sut = TrackReporter(mediaFacts: facts, tracker: tracker)

        // When
        let error = #expect(throws: AnalysisError.self) { try sut.report(of: "/abs/clip.mov", target: .area(area), at: 0.5) }

        // Then
        #expect(error == .targetNotFollowed(option: "--area", time: 0.5, file: "/abs/clip.mov"))
    }

    @Test("a failing tracker stops, naming `--area`, the video and the media time of `--at`")
    func namesFailingProvider() {
        // Given
        let sut = TrackReporter(mediaFacts: facts, tracker: FailingTracker(ProviderFailure("no model")))

        // When
        let error = #expect(throws: ProviderError.self) {
            try sut.report(of: "/abs/clip.mov", target: .area("[100, 100, 200, 40]"), at: 0.5)
        }

        // Then
        #expect(
            error?.description
                == #"--area (area): the tracker failed on "/abs/clip.mov" at media second 0.5: no model"#
        )
    }

    @Test("a quadrilateral followed by a perspective tracker prints its quad in perspective on every frame followed")
    func followsQuadInPerspective() throws {
        // Given
        let given = Quad(
            topLeft: Point(x: 100, y: 100),
            topRight: Point(x: 300, y: 120),
            bottomRight: Point(x: 290, y: 220),
            bottomLeft: Point(x: 110, y: 200)
        )
        let turned = Quad(
            topLeft: Point(x: 110, y: 90),
            topRight: Point(x: 280, y: 130),
            bottomRight: Point(x: 285, y: 210),
            bottomLeft: Point(x: 105, y: 215)
        )
        let tracker = QuadTrackerTable(base: given, quads: [(time: 0.25, quad: given), (time: 0.5, quad: turned)])
        let sut = TrackReporter(mediaFacts: facts, tracker: tracker)

        // When
        let report = try sut.report(
            of: "/abs/clip.mov",
            target: .quad("[[100, 100], [300, 120], [290, 220], [110, 200]]"),
            at: 0.25
        )

        // Then
        let expected = #"""
            {"track": "0.1.0", "time": 0.25, "frames": [\#
            {"time": 0.25, "quad": [[100, 100], [300, 120], [290, 220], [110, 200]]}, \#
            {"time": 0.5, "quad": [[110, 90], [280, 130], [285, 210], [105, 215]]}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("a quadrilateral reaching past the picture is carried from what the tracker follows of it to its whole plane")
    func carriesQuadPastPicture() throws {
        // Given
        // The tracker is given the rectangle bounding the part inside the 400 by 300 picture, which moves 10 pixels
        // right on the next frame, so the whole quadrilateral moves with it.
        let inside = Quad(Rectangle(x: 300, y: 100, width: 100, height: 100))
        let moved = Quad(Rectangle(x: 310, y: 100, width: 100, height: 100))
        let tracker = QuadTrackerTable(base: inside, quads: [(time: 0, quad: inside), (time: 0.25, quad: moved)])
        let sut = TrackReporter(mediaFacts: facts, tracker: tracker)

        // When
        let report = try sut.report(
            of: "/abs/clip.mov",
            target: .quad("[[300, 100], [500, 100], [500, 200], [300, 200]]"),
            at: 0
        )

        // Then
        let expected = #"""
            {"track": "0.1.0", "time": 0, "frames": [\#
            {"time": 0, "quad": [[300, 100], [500, 100], [500, 200], [300, 200]]}, \#
            {"time": 0.25, "quad": [[310, 100], [510, 100], [510, 200], [310, 200]]}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("a quadrilateral that is not four points of two numbers, or not strictly convex, stops, naming `--quad`", arguments: [
        ("[[0, 0], [10, 0], [10, 10]]", "--quad: a quadrilateral is four points [x, y] of numbers"),
        ("[[0, 0], [10, 0], [10, 10], [0]]", "--quad: a quadrilateral is four points [x, y] of numbers"),
        (#"[[0, 0], [10, 0], [10, 10], [0, "10"]]"#, "--quad: a quadrilateral is four points [x, y] of numbers"),
        ("[0, 0, 10, 10]", "--quad: a quadrilateral is four points [x, y] of numbers"),
        ("quad", "--quad: line 1, column 1: "),
        ("[[0, 0], [10, 10], [10, 0], [0, 10]]", "--quad: the quadrilateral is not strictly convex, so it is no plane to follow"),
        ("[[0, 0], [10, 0], [20, 0], [0, 10]]", "--quad: the quadrilateral is not strictly convex, so it is no plane to follow")
    ])
    func refusesBadQuad(quad: String, message: String) {
        // Given
        let sut = TrackReporter(mediaFacts: facts, tracker: tracker)

        // When
        let error = #expect(throws: (any Error).self) { try sut.report(of: "/abs/clip.mov", target: .quad(quad), at: 0.5) }

        // Then
        let description = error.map { String(describing: $0) } ?? ""
        #expect(description.hasPrefix(message), "\(description)")
    }

    @Test("a quadrilateral the tracker follows on no frame stops, naming `--quad`")
    func refusesQuadNotFollowed() {
        // Given
        let sut = TrackReporter(mediaFacts: facts, tracker: QuadTrackerTable(base: Quad(total), quads: []))

        // When
        let error = #expect(throws: AnalysisError.self) {
            try sut.report(of: "/abs/clip.mov", target: .quad("[[100, 100], [300, 100], [300, 140], [100, 140]]"), at: 0.5)
        }

        // Then
        #expect(error == .targetNotFollowed(option: "--quad", time: 0.5, file: "/abs/clip.mov"))
        #expect(error?.description.hasPrefix(#"--quad: the tracker follows the target on no frame of "/abs/clip.mov""#) == true)
    }

    @Test("a failing tracker given a quadrilateral stops, naming `--quad`")
    func namesFailingProviderOfQuad() {
        // Given
        let sut = TrackReporter(mediaFacts: facts, tracker: FailingTracker(ProviderFailure("no model")))

        // When
        let error = #expect(throws: ProviderError.self) {
            try sut.report(of: "/abs/clip.mov", target: .quad("[[100, 100], [300, 100], [300, 140], [100, 140]]"), at: 0.5)
        }

        // Then
        #expect(
            error?.description
                == #"--quad (quad): the tracker failed on "/abs/clip.mov" at media second 0.5: no model"#
        )
    }

    @Test("an image sequence is followed over its frames at their media times, frame index / fps")
    func followsImageSequence() throws {
        // Given
        let directory = try TemporaryDirectory()
        let facts = MediaFactTable(files: [:], imageSequences: [directory.path: ["0001.png", "0002.png", "0003.png"]])
        let tracker = TrackerTable(frameTimes: [directory.path: [0, 0.5, 1]], drift: Point(x: 0, y: -40))
        let sut = TrackReporter(mediaFacts: facts, tracker: tracker)

        // When
        let report = try sut.report(of: directory.path, fps: 2, target: .area("[10, 100, 100, 50]"), at: 0.5)

        // Then
        let expected = #"""
            {"track": "0.1.0", "time": 0.5, "frames": [\#
            {"time": 0, "quad": [[10, 120], [110, 120], [110, 170], [10, 170]]}, \#
            {"time": 0.5, "quad": [[10, 100], [110, 100], [110, 150], [10, 150]]}, \#
            {"time": 1, "quad": [[10, 80], [110, 80], [110, 130], [10, 130]]}]}
            """#
        #expect(report.machineOutput.written == expected)
    }

    @Test("an image sequence without a rate, a rate on a file and a time past an image sequence's end stop")
    func refusesImageSequenceRate() throws {
        // Given
        let directory = try TemporaryDirectory()
        let facts = MediaFactTable(
            files: self.facts.files,
            imageSequences: [directory.path: ["0001.png", "0002.png", "0003.png"]]
        )
        let sut = TrackReporter(mediaFacts: facts, tracker: tracker)

        // When
        let withoutRate = #expect(throws: AnalysisError.self) {
            try sut.report(of: directory.path, target: .area("[10, 100, 100, 50]"), at: 0)
        }
        let rateOfFile = #expect(throws: AnalysisError.self) {
            try sut.report(of: "/abs/clip.mov", fps: 2, target: .area("[10, 100, 100, 50]"), at: 0)
        }
        let pastEnd = #expect(throws: AnalysisError.self) {
            try sut.report(of: directory.path, fps: 2, target: .area("[10, 100, 100, 50]"), at: 1.5)
        }

        // Then
        #expect(withoutRate == .imageSequenceWithoutRate(directory: directory.path))
        #expect(rateOfFile == .rateOfFile(file: "/abs/clip.mov"))
        #expect(pastEnd == .atOrAfterMediaEnd(option: "--at", time: 1.5, file: directory.path, end: 1.5))
    }

    @Test("a real scrolling line is followed by the point tracker over every frame")
    func followsRealLine() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let video = directory.file("screen.mov")
        let drawn = try await ScreenRecording(scale: 0.5).write(to: video)
        let decoder = AVFoundationDecoder()
        let sut = TrackReporter(
            mediaFacts: decoder,
            tracker: PointTracker(decoder: decoder)
        )

        let line = drawn[15]

        // When
        let report = try sut.report(of: video, target: .area("[\(line.x), \(line.y), \(line.width), \(line.height)]"), at: 0.5)

        // Then
        #expect(report.frames.map(\.time) == ScreenRecording.frameTimes)
        let start = try #require(report.frames.first { $0.time == 0.5 })
        for (index, frame) in report.frames.enumerated() {
            let moved = frame.quad.centroid.y - start.quad.centroid.y
            let drift = drawn[index].center.y - drawn[15].center.y
            #expect(abs(moved - drift) <= 1.5, "frame \(index) moved \(moved), drawn \(drift)")
            #expect(abs(frame.quad.centroid.x - start.quad.centroid.x) <= 1.5, "frame \(index) moved along")
        }
    }

    // MARK: - Private
}

//
//  AnalysisCommandTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import FramesTestMedia
import Testing

@testable import Frames
@testable import FramesCommand

// `probe`, `ocr`, `track`, `evaluate` and `locate` run end to end on the real roles and providers. Serialized, since
// AVAssetReader needs a free thread of the shared pool.
@Suite("AnalysisCommand Tests", .serialized)
struct AnalysisCommandTests {
    // MARK: - Property
    private let sut: TestShell

    // MARK: - Initializer
    init() throws {
        sut = try TestShell()
    }

    // MARK: - Test
    @Test("probe prints a video's facts for people, one a line")
    func printsProbeText() async throws {
        // Given
        let video = try await movie(named: "clip.mov")

        // When
        let code = sut.run(["probe", video])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == "kind video\nsize 64x48\nduration 1\nfps 2\nalpha no\ncolor space srgb, 8 bit\naudio none\n")
    }

    @Test("probe --json prints the probe object, its first key the command set to the version")
    func printsProbeMachineOutput() async throws {
        // Given
        let video = try await movie(named: "clip.mov")

        // When
        let code = sut.run(["probe", video, "--json"])

        // Then
        #expect(code == 0)
        #expect(try keys(of: sut.standardOutput) == ["probe", "kind", "size", "duration", "fps", "alpha", "colorSpace", "audio"])
        #expect(sut.standardOutput.hasPrefix("{\n  \"probe\": \"\(FramesVersion.current)\",\n  \"kind\": \"video\","))
    }

    @Test("ocr prints an image's size and its lines for people, or with --json the ocr object")
    func printsOCR() throws {
        // Given
        let image = sut.directory.file("card.png")
        try ImageWriter(size: Size(width: 720, height: 400)).write(to: image) { canvas in
            canvas.fill(red: 255, green: 255, blue: 255)
            canvas.draw("Send message", font: "Helvetica", size: 48, x: 60, y: 200)
        }

        // When
        let textCode = sut.run(["ocr", image])
        let text = sut.standardOutput
        let machineCode = sut.run(["ocr", image, "--json"])
        let machine = sut.standardOutput
        let languagesCode = sut.run(["--ocr-languages", "ko-KR", "ocr", image, "--languages", "en-US", "--json"])
        let languages = try JSONReader().read(sut.standardOutput).objectValue?["languages"]
        let unsupportedCode = sut.run(["ocr", image, "--languages", "tlh-AQ"])

        // Then
        let lines = text.split(separator: "\n")
        #expect(textCode == 0)
        #expect(machineCode == 0)
        #expect(lines.first == "size 720x400")
        #expect(lines.count == 2 && lines.last?.hasSuffix("]  Send message") == true)
        #expect(try keys(of: machine) == ["ocr", "size", "languages", "frames"])
        #expect(machine.contains(#""languages": null"#))
        #expect(machine.contains(#""text": "Send message""#))
        #expect(languagesCode == 0)
        #expect(languages == .array([.string("en-US")]))
        #expect(unsupportedCode == 1)
        #expect(sut.standardError.contains("cannot recognise the language tlh-AQ"))
    }

    @Test("ocr of an image with --at stops with the reporter's reason")
    func stopsOCRAtOnImage() throws {
        // Given
        let image = sut.directory.file("card.png")
        try ImageWriter(size: Size(width: 32, height: 18)).write(to: image) { _ in }

        // When
        let code = sut.run(["ocr", image, "--at", "0"])

        // Then
        #expect(code == 1)
        #expect(sut.standardError == """
            frames: media "\(image)" is an image, whose one frame is at time 0, so it takes neither --at nor a range

            """)
    }

    @Test("track always prints the track object, one frame for each frame followed")
    func printsTrack() async throws {
        // Given
        let video = sut.directory.file("square.mov")
        let writer = MovieWriter(size: Size(width: 64, height: 48), frameTimes: [0, 0.1, 0.2], end: 0.3)
        try await writer.write(to: video) { canvas, _ in
            canvas.fill(red: 0, green: 0, blue: 0)
            canvas.fill(Rectangle(x: 24, y: 16, width: 16, height: 16), red: 255, green: 255, blue: 255)
        }

        // When
        let code = sut.run(["track", video, "--at", "0", "--area", "[24, 16, 16, 16]"])

        // Then
        #expect(code == 0, "\(sut.standardError)")
        #expect(try keys(of: sut.standardOutput) == ["track", "time", "target", "frames"])
        #expect(try frameCount(in: sut.standardOutput) == 3)
    }

    @Test("evaluate always prints the evaluate object of a document at a time, from the document or its resolved one")
    func printsEvaluation() throws {
        // Given
        let document = try sut.write(sequence, named: "doc.json")
        let resolved = sut.directory.file("resolved.json")
        sut.run(["resolve", document, "-o", resolved])

        // When
        let code = sut.run(["evaluate", document, "--at", "0.25"])
        let output = sut.standardOutput
        let resolvedCode = sut.run(["evaluate", resolved, "--at", "0.25"])

        // Then
        #expect(code == 0)
        #expect(resolvedCode == 0)
        #expect(try keys(of: output) == ["evaluate", "time", "size", "items"])
        #expect(output.hasPrefix("{\n  \"evaluate\": \"\(FramesVersion.current)\",\n  \"time\": 0.25,"))
        #expect(output.contains(#""place": "storyline[0]""#))
        #expect(sut.standardOutput == output)
    }

    @Test("locate always prints the locate object of what is under a point of the output")
    func printsLocation() throws {
        // Given
        let document = try sut.write(sequence, named: "doc.json")

        // When
        let code = sut.run(["locate", document, "--at", "0.75", "--point", "80,45"])

        // Then
        #expect(code == 0)
        #expect(try keys(of: sut.standardOutput) == ["locate", "hits"])
        #expect(sut.standardOutput.contains(#""place": "storyline[1]""#))
    }

    @Test("evaluate and locate stop on --at outside the sequence, as still does", arguments: [
        ("evaluate", "1", [String]()),
        ("locate", "-0.5", ["--point", "80,45"])
    ])
    func stopsOnTimeOutsideSequence(
        command: String,
        time: String,
        options: [String]
    ) throws {
        // Given
        let document = try sut.write(sequence, named: "doc.json")

        // When
        let code = sut.run([command, document, "--at", time] + options)

        // Then
        #expect(code == 1)
        #expect(sut.standardError == """
            frames: --at \(time): the sequence has no frame then, since it runs over [0, 1)

            """)
    }

    // MARK: - Private
    private var sequence: String {
        #"""
        { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 },
          "storyline": [ { "solid": "#FF8000", "duration": 0.5 }, { "solid": "#0000FF", "duration": 0.5 } ] }
        """#
    }

    // One second at 2 frames a second, grey.
    private func movie(named name: String) async throws -> String {
        let file = sut.directory.file(name)
        let writer = MovieWriter(size: Size(width: 64, height: 48), frameTimes: [0, 0.5], end: 1)
        try await writer.write(to: file) { canvas, _ in
            canvas.fill(red: 128, green: 128, blue: 128)
        }

        return file
    }

    // The keys of the printed object, in the order it holds them.
    private func keys(of output: String) throws -> [String] {
        let object = try #require(try JSONReader().read(Data(output.utf8)).objectValue)

        return object.keys
    }

    private func frameCount(in output: String) throws -> Int {
        let object = try #require(try JSONReader().read(Data(output.utf8)).objectValue)

        return try #require(object["frames"]?.arrayValue).count
    }
}

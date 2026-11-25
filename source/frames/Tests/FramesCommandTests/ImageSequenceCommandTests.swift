//
//  ImageSequenceCommandTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/25/26.
//

import Foundation
import FramesTestMedia
import Testing

@testable import Frames
@testable import FramesCommand

// `ocr`, `track`, `extract` and `sheet` read an image sequence's directory at the rate `--fps` gives it, end to end on the real
// roles and providers. Serialized, as the other end to end suites are.
@Suite("ImageSequenceCommand Tests", .serialized)
struct ImageSequenceCommandTests {
    // MARK: - Property
    private let sut: TestShell
    // One word on each frame, in frame order.
    private let words = ["Alpha", "Bravo", "Charlie"]

    // MARK: - Initializer
    init() throws {
        sut = try TestShell()
    }

    // MARK: - Test
    @Test("ocr reads the frame of an image sequence shown at a media time, its media time frame index / --fps")
    func readsFrameAtTime() throws {
        // Given
        let directory = try imageSequence()

        // When
        let code = sut.run(["ocr", directory, "--fps", "2", "--at", "0.75", "--json"])

        // Then
        #expect(code == 0, "\(sut.standardError)")
        let frames = try frames(in: sut.standardOutput)
        #expect(frames.map { $0.time } == [0.75])
        #expect(frames.map { $0.text } == [["Bravo"]])
    }

    @Test("ocr reads an image sequence over a range of media times, from time 0 without --at or a range")
    func readsRange() throws {
        // Given
        let directory = try imageSequence()

        // When
        let rangeCode = sut.run(["ocr", directory, "--fps", "2", "--from", "0", "--to", "1.5", "--step", "0.5", "--json"])
        let range = try frames(in: sut.standardOutput)
        let firstCode = sut.run(["ocr", directory, "--fps", "2"])

        // Then
        #expect(rangeCode == 0, "\(sut.standardError)")
        #expect(range.map { $0.time } == [0, 0.5, 1])
        #expect(range.map { $0.text } == words.map { [$0] })
        #expect(firstCode == 0)
        #expect(sut.standardOutput.split(separator: "\n").first == "size 720x400")
        #expect(sut.standardOutput.split(separator: "\n").last?.hasSuffix("]  Alpha") == true)
    }

    @Test("extract writes an image sequence's frames at media times, and sheet lays them out, at the rate --fps gives")
    func extractsAndSheets() throws {
        // Given
        let directory = try imageSequence()
        let output = sut.directory.file("out")
        let sheet = sut.directory.file("sheet.png")

        // When
        let extractCode = sut.run(["extract", directory, output, "--fps", "4", "--step", "0.25"])
        let extracted = sut.standardOutput
        let sheetCode = sut.run(["sheet", directory, "-o", sheet, "--fps", "2", "--step", "0.5"])

        // Then
        let files = ["0000.png", "0001.png", "0002.png"].map { (output as NSString).appendingPathComponent($0) }
        #expect(extractCode == 0, "\(sut.standardError)")
        #expect(extracted.split(separator: "\n").map { String($0.split(separator: " ").first ?? "") } == files)
        #expect(sheetCode == 0, "\(sut.standardError)")
        #expect(sut.standardOutput.hasPrefix("\(sheet)  "))
        #expect(FileManager.default.fileExists(atPath: sheet))
    }

    @Test("track follows a target over an image sequence's frames at their media times, frame index / --fps")
    func tracksImageSequence() throws {
        // Given
        // A white square moves 2 pixels right on each frame of a black picture.
        let directory = sut.directory.file("square")
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        for index in 0..<3 {
            let file = (directory as NSString).appendingPathComponent("frame-\(index + 1).png")
            try ImageWriter(size: Size(width: 64, height: 48)).write(to: file) { canvas in
                canvas.fill(red: 0, green: 0, blue: 0)
                canvas.fill(Rectangle(x: 20 + 2 * Double(index), y: 16, width: 16, height: 16), red: 255, green: 255, blue: 255)
            }
        }

        // When
        let code = sut.run(["track", directory, "--fps", "4", "--at", "0.25", "--area", "[22, 16, 16, 16]"])

        // Then
        #expect(code == 0, "\(sut.standardError)")
        let printed = try JSONReader().read(sut.standardOutput).objectValue
        let frames = printed?["frames"]?.arrayValue?.compactMap(\.objectValue) ?? []
        #expect(printed?["time"]?.numberValue == 0.25)
        #expect(frames.map { $0["time"]?.numberValue ?? -1 } == [0, 0.25, 0.5])
        let lefts = frames.map { $0["quad"]?.arrayValue?.first?.arrayValue?.first?.numberValue ?? -1 }
        for (left, expected) in zip(lefts, [20.0, 22, 24]) {
            #expect(abs(left - expected) <= 0.5, "\(lefts)")
        }
    }

    @Test("a time past an image sequence's frame count / --fps stops as one past a video's end does")
    func stopsPastEnd() throws {
        // Given
        let directory = try imageSequence()

        // When
        let code = sut.run(["extract", directory, sut.directory.file("out"), "--fps", "2", "--to", "2"])

        // Then
        #expect(code == 1)
        #expect(sut.standardError == "frames: --to 2: past the end of the image sequence at 1.5\n")
    }

    @Test("a directory without --fps stops, naming --fps, in each command that reads it", arguments: ["ocr", "track", "extract", "sheet"])
    func stopsWithoutRate(command: String) throws {
        // Given
        let directory = try imageSequence()
        let options = switch command {
        case "extract": [sut.directory.file("out")]
        case "sheet": ["-o", sut.directory.file("sheet.png")]
        case "track": ["--at", "0", "--area", "[0, 0, 10, 10]"]
        default: [String]()
        }

        // When
        let code = sut.run([command, directory] + options)

        // Then
        #expect(code == 1)
        #expect(sut.standardError == """
            frames: media "\(directory)" is an image sequence, whose files give no rate, so --fps gives it, as its media form's fps does

            """)
    }

    @Test("--fps on a file stops, since the file gives its own rate, and on a document, whose frames are at sequence times")
    func stopsRateOfFile() throws {
        // Given
        let image = sut.directory.file("card.png")
        try ImageWriter(size: Size(width: 32, height: 18)).write(to: image) { _ in }
        let document = try sut.write(##"{ "kind": "sequence", "storyline": [ { "kind": "solid", "color": "#000000", "duration": 1 } ] }"##, named: "doc.json")

        // When
        let fileCode = sut.run(["ocr", image, "--fps", "2"])
        let fileError = sut.standardError
        let documentCode = sut.run(["sheet", document, "-o", sut.directory.file("sheet.png"), "--fps", "2"])

        // Then
        #expect(fileCode == 1)
        #expect(fileError == "frames: --fps: media \"\(image)\" is no image sequence directory, and a file gives its own rate\n")
        #expect(documentCode == 1)
        #expect(sut.standardError == "frames: sheet: --fps gives an image sequence its rate, and a document's frames are at sequence times\n")
    }

    // MARK: - Private
    // A directory of one PNG for each word, numbered from 1 in natural order.
    private func imageSequence() throws -> String {
        let directory = sut.directory.file("frames")
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        for (index, word) in words.enumerated() {
            let file = (directory as NSString).appendingPathComponent("frame-\(index + 1).png")
            try ImageWriter(size: Size(width: 720, height: 400)).write(to: file) { canvas in
                canvas.fill(red: 255, green: 255, blue: 255)
                canvas.draw(word, font: "Helvetica", size: 64, x: 60, y: 200)
            }
        }

        return directory
    }

    // Each frame's media time and the text of its lines.
    private func frames(in output: String) throws -> [(time: Double, text: [String])] {
        let frames = try JSONReader().read(output).objectValue?["frames"]?.arrayValue?.compactMap(\.objectValue) ?? []

        return frames.map { frame in
            let lines = frame["lines"]?.arrayValue?.compactMap { $0.objectValue?["text"]?.stringValue } ?? []
            return (time: frame["time"]?.numberValue ?? -1, text: lines)
        }
    }
}

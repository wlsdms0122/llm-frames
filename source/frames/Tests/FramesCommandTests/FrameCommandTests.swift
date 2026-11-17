//
//  FrameCommandTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames
import FramesTestMedia
import Testing

@testable import FramesCommand

// `still`, `sheet` and `extract` run end to end on the real roles. Serialized, since AVAssetReader needs a free thread
// of the shared pool.
@Suite("FrameCommand Tests", .serialized)
struct FrameCommandTests {
    // MARK: - Property
    private let sut: TestShell

    // MARK: - Initializer
    init() throws {
        sut = try TestShell()
    }

    // MARK: - Test
    @Test("still draws a document's frames at the times --at gives to one PNG, from the document or its resolved one")
    func drawsStill() throws {
        // Given
        let document = try sut.write(sequence, named: "doc.json")
        let resolved = sut.directory.file("resolved.json")
        let output = sut.directory.file("still.png")
        let again = sut.directory.file("again.png")
        sut.run(["resolve", document, "-o", resolved])

        // When
        let code = sut.run(["still", document, "--at", "0.2,0.7", "-o", output])
        let printed = sut.standardOutput
        let resolvedCode = sut.run(["still", resolved, "--at", "0.2", "-o", again])

        // Then
        #expect(code == 0)
        #expect(resolvedCode == 0)
        #expect(try printed == line(of: output))
        #expect(try sut.standardOutput == line(of: again))
    }

    @Test("still of an image document stops with the exporter's reason and writes nothing")
    func stopsStillOfImage() throws {
        // Given
        let image = try picture(named: "card.png")
        let document = try sut.write(#"{ "kind": "image", "source": "\#(image)" }"#, named: "card.json")
        let output = sut.directory.file("still.png")

        // When
        let code = sut.run(["still", document, "--at", "0", "-o", output])

        // Then
        #expect(code == 1)
        #expect(sut.standardError == "frames: image documents have no sequence times, so they have no frames to take\n")
        #expect(!FileManager.default.fileExists(atPath: output))
    }

    @Test("sheet lays out a video's frames or a document's on one PNG and prints its line")
    func drawsSheet() async throws {
        // Given
        let video = try await movie(named: "clip.mov")
        let document = try sut.write(sequence, named: "doc.json")
        let videoSheet = sut.directory.file("video.png")
        let documentSheet = sut.directory.file("document.png")

        // When
        let videoCode = sut.run(["sheet", video, "-o", videoSheet, "--step", "0.5", "--cols", "2"])
        let videoOutput = sut.standardOutput
        let documentCode = sut.run(["sheet", document, "-o", documentSheet, "--from", "0.5"])

        // Then
        #expect(videoCode == 0)
        #expect(documentCode == 0)
        #expect(try videoOutput == line(of: videoSheet))
        #expect(try sut.standardOutput == line(of: documentSheet))
    }

    @Test("extract writes a video's frames as numbered PNGs in a directory it makes, one line for each")
    func extractsFrames() async throws {
        // Given
        let video = try await movie(named: "clip.mov")
        let directory = sut.directory.file("frames")

        // When
        let code = sut.run(["extract", video, directory, "--step", "0.5"])

        // Then
        let files = ["0000.png", "0001.png"].map { (directory as NSString).appendingPathComponent($0) }
        #expect(code == 0)
        #expect(try sut.standardOutput == files.map(line).joined())
    }

    @Test("extract of a range past the video's end stops before the directory is made")
    func stopsExtractPastEnd() async throws {
        // Given
        let video = try await movie(named: "clip.mov")
        let directory = sut.directory.file("frames")

        // When
        let code = sut.run(["extract", video, directory, "--to", "2"])

        // Then
        #expect(code == 1)
        #expect(sut.standardError == "frames: --to 2: past the end of the video at 1\n")
        #expect(!FileManager.default.fileExists(atPath: directory))
    }

    // MARK: - Private
    private var sequence: String {
        #"""
        { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 },
          "storyline": [ { "solid": "#FF8000", "duration": 0.5 }, { "solid": "#0000FF", "duration": 0.5 } ] }
        """#
    }

    private func picture(named name: String) throws -> String {
        let file = sut.directory.file(name)
        try ImageWriter(size: Size(width: 32, height: 18)).write(to: file) { canvas in
            canvas.fill(red: 255, green: 128, blue: 0)
        }

        return file
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

    private func line(of path: String) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? -1

        return "\(path)  \(FileSize(bytes: bytes))\n"
    }
}

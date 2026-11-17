//
//  DocumentCommandTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Frames
import FramesTestMedia
import Testing

@testable import FramesCommand

// `resolve`, `timeline` and `render` run end to end on the real roles. Serialized, since AVAssetReader needs a free
// thread of the shared pool and a render encodes.
@Suite("DocumentCommand Tests", .serialized)
struct DocumentCommandTests {
    // MARK: - Property
    private let sut: TestShell

    // MARK: - Initializer
    init() throws {
        sut = try TestShell()
        try sut.write(#"{ "description": "fades", "seconds": 0.5 }"#, to: sut.framesPresets.appendingPathComponent("transition/fade.json"))
    }

    // MARK: - Test
    @Test("resolve writes the resolved document of a sequence and prints its path and size")
    func resolvesSequence() throws {
        // Given
        let image = try picture(named: "card.png")
        let document = try sut.write(#"{ "kind": "sequence", "storyline": [ { "media": "\#(image)", "duration": 1 } ] }"#, named: "card.json")
        let output = sut.directory.file("card.resolved.json")

        // When
        let code = sut.run(["resolve", document, "-o", output])

        // Then
        let text = try String(contentsOfFile: output, encoding: .utf8)
        #expect(code == 0)
        #expect(sut.standardError.isEmpty)
        #expect(try sut.standardOutput == line(of: output))
        #expect(text.hasPrefix("{\n  \"kind\": \"sequence\",\n  \"resolved\": \"1.0.0\""))
    }

    @Test("resolve of a resolved document writes it as it is")
    func resolvesResolvedDocument() throws {
        // Given
        let document = try sut.write(sequence, named: "doc.json")
        let first = sut.directory.file("first.json")
        let second = sut.directory.file("second.json")
        sut.run(["resolve", document, "-o", first])

        // When
        let code = sut.run(["resolve", first, "-o", second])

        // Then
        #expect(code == 0)
        #expect(try Data(contentsOf: URL(fileURLWithPath: second)) == Data(contentsOf: URL(fileURLWithPath: first)))
    }

    @Test("resolve -o names a .json file, whatever its case, and another extension stops before anything is read")
    func stopsOnResolvedExtension() throws {
        // Given
        let document = try sut.write(sequence, named: "doc.json")
        let upper = sut.directory.file("upper.JSON")
        let other = sut.directory.file("resolved.txt")

        // When
        let upperCode = sut.run(["resolve", document, "-o", upper])
        let otherCode = sut.run(["resolve", sut.directory.file("absent.json"), "-o", other])

        // Then
        #expect(upperCode == 0)
        #expect(otherCode == 1)
        #expect(sut.standardError == "frames: resolve: \"\(other)\": a resolved document is written to a .json file\n")
        #expect(!FileManager.default.fileExists(atPath: other))
    }

    @Test("timeline prints one line per clip for people")
    func printsTimelineText() throws {
        // Given
        let document = try sut.write(sequence, named: "doc.json")

        // When
        let code = sut.run(["timeline", document])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == """
            duration 1.5
            storyline[0]  -  edit [0, 1)  drawn [0, 1.25)  clip [0, 1)  speed 1  transition none
            storyline[1]#end  -  edit [1, 1.5)  drawn [0.75, 1.5)  clip [0, 0.5)  speed 1  transition frames/fade 0.5

            """)
    }

    @Test("timeline --json of a resolved document is the document's own, with no preset names")
    func printsResolvedTimeline() throws {
        // Given
        let document = try sut.write(sequence, named: "doc.json")
        let resolved = sut.directory.file("resolved.json")
        sut.run(["resolve", document, "-o", resolved])

        // When
        let documentOutput = timelineOutput(of: document)
        let resolvedOutput = timelineOutput(of: resolved)

        // Then
        #expect(documentOutput.contains(#""preset": "frames/fade""#))
        #expect(resolvedOutput == documentOutput.replacingOccurrences(of: #""preset": "frames/fade""#, with: #""preset": null"#))
    }

    @Test("a document is also read from standard input")
    func readsStandardInput() {
        // Given, When
        let code = sut.run(["timeline", "-", "--json"], input: sequence)

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput.hasPrefix("{\n  \"timeline\": \"1.0.0\",\n  \"duration\": 1.5,"))
    }

    @Test("a pack template named <pack>/<name> takes its defaults, or the arguments --args gives")
    func readsPackTemplate() throws {
        // Given
        let pack = try sut.addPack("shorts")
        try sut.write(
            #"""
            { "kind": "sequence", "format": { "size": [160, 90] },
              "params": { "length": { "type": "number", "default": 1 } },
              "storyline": [ { "solid": "#000000", "duration": { "param": "length" } } ] }
            """#,
            to: pack.appendingPathComponent("templates/card.json")
        )
        let arguments = try sut.write(#"{ "length": 2 }"#, named: "args.json")

        // When
        let defaults = sut.run(["timeline", "shorts/card"])
        let defaultOutput = sut.standardOutput
        let argued = sut.run(["timeline", "shorts/card", "--args", arguments])

        // Then
        #expect(defaults == 0)
        #expect(argued == 0)
        #expect(defaultOutput.hasPrefix("duration 1\n"))
        #expect(sut.standardOutput.hasPrefix("duration 2\n"))
    }

    @Test("render draws the frame of a sequence at --at to one PNG and prints its path and size")
    func rendersFrame() throws {
        // Given
        let document = try sut.write(sequence, named: "doc.json")
        let output = sut.directory.file("out.png")

        // When
        let code = sut.run(["render", document, "-o", output, "--at", "1.2"])

        // Then
        #expect(code == 0)
        #expect(sut.standardError.isEmpty)
        #expect(try sut.standardOutput == line(of: output))
    }

    @Test("render writes a sequence's master and delivery, one line for each, from the document or its resolved document")
    func rendersSequence() throws {
        // Given
        let image = try picture(named: "frame.png")
        let document = try sut.write(
            #"{ "kind": "sequence", "format": { "fps": 10 }, "storyline": [ { "media": "\#(image)", "duration": 0.3 } ] }"#,
            named: "doc.json"
        )
        let resolved = sut.directory.file("resolved.json")
        let master = sut.directory.file("out.mov")
        let delivery = sut.directory.file("out.mp4")
        let again = sut.directory.file("again.mov")
        sut.run(["resolve", document, "-o", resolved])

        // When
        let code = sut.run(["render", document, "-o", master, "--deliver", delivery])
        let output = sut.standardOutput
        let resolvedCode = sut.run(["render", resolved, "-o", again])

        // Then
        #expect(code == 0)
        #expect(resolvedCode == 0)
        #expect(try output == line(of: master) + line(of: delivery))
        #expect(try sut.standardOutput == line(of: again))
    }

    @Test("render to another extension, or with --at to a master, stops with the pipeline's reason", arguments: [
        ("out.gif", [] as [String], "render writes a .mov master or a .png frame"),
        ("out.mov", ["--at", "1"], "--at picks the frame of a .png, and a .mov master holds every frame")
    ])
    func stopsOnOutput(
        name: String,
        options: [String],
        reason: String
    ) throws {
        // Given
        let document = try sut.write(sequence, named: "doc.json")
        let output = sut.directory.file(name)

        // When
        let code = sut.run(["render", document, "-o", output] + options)

        // Then
        #expect(code == 1)
        #expect(sut.standardError == "frames: \"\(output)\": \(reason)\n")
        #expect(!FileManager.default.fileExists(atPath: output))
    }

    // MARK: - Private
    private var sequence: String {
        #"""
        { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 },
          "storyline": [
            { "solid": "#000000", "duration": 1 },
            { "id": "end", "solid": "#FFFFFF", "duration": 0.5, "transition": { "preset": "frames/fade", "seconds": 0.5 } }
          ] }
        """#
    }

    private func picture(named name: String) throws -> String {
        let file = sut.directory.file(name)
        try ImageWriter(size: Size(width: 32, height: 18)).write(to: file) { canvas in
            canvas.fill(red: 255, green: 128, blue: 0)
        }

        return file
    }

    private func line(of path: String) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? -1

        return "\(path)  \(FileSize(bytes: bytes))\n"
    }

    private func timelineOutput(of document: String) -> String {
        sut.run(["timeline", document, "--json"])

        return sut.standardOutput
    }
}

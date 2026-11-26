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

// `resolve`, `timeline` and `render` run end to end on the real roles. Serialized, so that the tests running at once
// read far fewer files with AVFoundation than the 64 at once at which its reads stop finishing (FRAMES-21 Notes), and
// since a render encodes.
@Suite("DocumentCommand Tests", .serialized, .ownThread)
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
        let document = try sut.write(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "\#(image)", "duration": 1 } ] }"#, named: "card.json")
        let output = sut.directory.file("card.resolved.json")

        // When
        let code = sut.run(["resolve", document, "-o", output])

        // Then
        let text = try String(contentsOfFile: output, encoding: .utf8)
        #expect(code == 0)
        #expect(sut.standardError.isEmpty)
        #expect(try sut.standardOutput == line(of: output))
        #expect(text.hasPrefix("{\n  \"kind\": \"sequence\",\n  \"resolved\": \"0.1.0\""))
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
            storyline[0]  solid  -  edit [0, 1)  drawn [0, 1.25)  clip [0, 1)  sound -  speed 1  transition none
            storyline[1]#end  solid  -  edit [1, 1.5)  drawn [0.75, 1.5)  clip [0, 0.5)  sound -  speed 1  transition frames/fade 0.5

            """)
    }

    @Test("timeline --json of a resolved document is the document's own, with no preset names, no instants and every clock on sequence time")
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
        #expect(documentOutput.contains(#""instant": 1,"#))
        #expect(documentOutput.contains(#""clip": "storyline[1]#end","#))
        var expected = try #require(JSONSerialization.jsonObject(with: Data(documentOutput.utf8)) as? [String: Any])
        for key in ["storyline", "clips"] {
            expected[key] = try #require(expected[key] as? [[String: Any]]).map { entry in
                var entry = entry
                entry["instant"] = NSNull()
                entry["clock"] = ["clip": NSNull(), "origin": 0, "speed": 1] as [String: Any]
                if var transition = entry["transition"] as? [String: Any] {
                    transition["preset"] = NSNull()
                    entry["transition"] = transition
                }

                return entry
            }
        }
        let timeline = try #require(JSONSerialization.jsonObject(with: Data(resolvedOutput.utf8)) as? [String: Any])
        #expect(NSDictionary(dictionary: timeline) == NSDictionary(dictionary: expected))
    }

    @Test("a document is also read from standard input")
    func readsStandardInput() {
        // Given, When
        let code = sut.run(["timeline", "-", "--json"], input: sequence)

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput.hasPrefix("{\n  \"timeline\": \"0.1.0\",\n  \"duration\": 1.5,"))
    }

    @Test("a document that is not JSON stops naming it by its path, as standard input, or as <pack>/<name>, then where reading it stops")
    func namesBrokenDocument() throws {
        // Given
        let broken = #"{ "kind": "sequence", oops }"#
        let document = try sut.write(broken, named: "broken.json")
        let pack = try sut.addPack("shorts")
        try sut.write(broken, to: pack.appendingPathComponent("templates/broken.json"))

        // When
        let pathCode = sut.run(["timeline", document])
        let pathError = sut.standardError
        let inputCode = sut.run(["timeline", "-"], input: broken)
        let inputError = sut.standardError
        let templateCode = sut.run(["timeline", "shorts/broken"])

        // Then
        #expect([pathCode, inputCode, templateCode] == [1, 1, 1])
        #expect(pathError == "frames: \(document): line 1, column 23: expected a key in quotes\n")
        #expect(inputError == "frames: standard input: line 1, column 23: expected a key in quotes\n")
        #expect(sut.standardError == "frames: shorts/broken: line 1, column 23: expected a key in quotes\n")
    }

    @Test(
        "a document whose first character other than white space is not { is said to be no frames document",
        arguments: [
            ("\u{0}\u{0}\u{0}\u{18}ftypmp42", "line 1, column 1: unexpected character"),
            ("\n  hello", "line 2, column 3: unexpected character"),
            ("", "line 1, column 1: unexpected end of input")
        ]
    )
    func refusesNonDocument(
        text: String,
        reason: String
    ) throws {
        // Given
        let media = try sut.write(text, named: "shot.mov")

        // When
        let pathCode = sut.run(["timeline", media])
        let pathError = sut.standardError
        let inputCode = sut.run(["timeline", "-"], input: text)

        // Then
        #expect(pathCode == 1)
        #expect(inputCode == 1)
        #expect(pathError == "frames: \(media): \(reason), so this is not a frames document, which is a JSON object\n")
        #expect(sut.standardError == "frames: standard input: \(reason), so this is not a frames document, which is a JSON object\n")
    }

    @Test("a pack template named <pack>/<name> takes its defaults, or the arguments --args gives")
    func readsPackTemplate() throws {
        // Given
        let pack = try sut.addPack("shorts")
        try sut.write(
            #"""
            { "kind": "sequence", "format": { "size": [160, 90] },
              "params": { "length": { "type": "number", "default": 1, "description": "the length" } },
              "storyline": [ { "kind": "solid", "color": "#000000", "duration": { "param": "length" } } ] }
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

    @Test("a pack template named <pack>/<name> is read in its pack, so its theme's and its titles' fonts are looked for there first")
    func findsPackTemplateFonts() throws {
        // Given
        let pack = try sut.addPack("shorts")
        let font = pack.appendingPathComponent("fonts/Courier.ttc")
        try FileManager.default.createDirectory(at: font.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/System/Library/Fonts/Courier.ttc"), to: font)
        try sut.write(
            #"""
            { "kind": "sequence", "format": { "size": [160, 90] }, "theme": { "font": ["Courier"] },
              "storyline": [ { "kind": "solid", "color": "#000000", "duration": 1 } ],
              "clips": [ { "kind": "title", "text": "a", "style": "title", "position": [80, 45], "at": [0, 1] },
                         { "kind": "title", "text": "b", "style": "title", "character": { "font": ["Courier"] }, "position": [80, 45], "at": [0, 1] } ] }
            """#,
            to: pack.appendingPathComponent("templates/card.json")
        )
        let output = sut.directory.file("card.resolved.json")

        // When
        let code = sut.run(["resolve", "shorts/card", "-o", output])

        // Then
        let text = try String(contentsOfFile: output, encoding: .utf8)
        #expect(code == 0)
        #expect(text.components(separatedBy: #""file": "\#(font.path)""#).count == 3)
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
        #expect(sut.standardError == "frame 1/1\n")
        #expect(try sut.standardOutput == line(of: output))
    }

    @Test("render writes a sequence's master and delivery, one line for each, from the document or its resolved document")
    func rendersSequence() throws {
        // Given
        let image = try picture(named: "frame.png")
        let document = try sut.write(
            #"{ "kind": "sequence", "format": { "fps": 10 }, "storyline": [ { "kind": "media", "media": "\#(image)", "duration": 0.3 } ] }"#,
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

    @Test("render to another extension, or with --at to a video, stops with the pipeline's reason", arguments: [
        ("out.gif", [] as [String], "render writes a .mov master, an .mp4 delivery or a .png frame"),
        ("out.mov", ["--at", "1"], "--at picks the frame of a .png, and a video holds every frame"),
        ("out.mp4", ["--at", "1"], "--at picks the frame of a .png, and a video holds every frame")
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

    @Test("render --report writes the run's report with every field, its stages adding up to its seconds, and prints its line after the video's")
    func writesReport() throws {
        // Given
        let image = try picture(named: "frame.png")
        let document = try sut.write(
            #"{ "kind": "sequence", "format": { "fps": 10 }, "storyline": [ { "kind": "media", "media": "\#(image)", "duration": 0.3 } ] }"#,
            named: "doc.json"
        )
        let master = sut.directory.file("out.mov")
        let report = sut.directory.file("run.JSON")

        // When
        let code = sut.run(["render", document, "-o", master, "--report", report, "--progress", "none"])

        // Then
        #expect(code == 0)
        #expect(sut.standardError.isEmpty)
        #expect(try sut.standardOutput == line(of: master) + line(of: report))
        let text = try String(contentsOfFile: report, encoding: .utf8)
        let object = try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        let keys = ["render", "frames", "seconds", "cpuSeconds", "fps", "cores", "peakMemory", "machine", "roles", "stages", "readAhead", "waiting", "other", "media", "files", "memory"]
        #expect(Set(object.keys) == Set(keys))
        #expect(keys.map { text.range(of: "\"\($0)\":")!.lowerBound } == keys.map { text.range(of: "\"\($0)\":")!.lowerBound }.sorted())
        #expect(object["frames"] as? Int == 3)
        let stages = try #require(object["stages"] as? [String: Double])
        #expect(Set(stages.keys) == Set(RunStage.allCases.map(\.rawValue)))
        let seconds = try #require(object["seconds"] as? Double)
        let renderThread = RunStage.allCases.filter(\.isOnRenderThread).reduce(0) { $0 + stages[$1.rawValue]! }
        let readAhead = try #require(object["readAhead"] as? [String: Double])
        #expect(Set(readAhead.keys) == ["decode", "workingConversion"])
        let waiting = try #require(object["waiting"] as? [String: Double])
        #expect(Set(waiting.keys) == ["encoder", "decoder"])
        let other = try #require(object["other"] as? Double)
        let held = renderThread - readAhead.values.reduce(0, +) + waiting.values.reduce(0, +)
        #expect(abs(held + other - seconds) < 1e-5)
        #expect(other >= 0)
        let roles = try #require(object["roles"] as? [String: String])
        #expect(roles == ["decoder": "avfoundation", "renderer": "quartz", "mixer": "avfoundation", "encoder": "avfoundation"])
        let media = try #require(object["media"] as? [[String: Any]])
        #expect(media.count == 1)
        #expect(media.first?["path"] as? String == image)
        #expect(media.first?["conversion"] as? String == "none")
        #expect(media.first?["colorSpace"] as? String == "srgb")
        #expect((media.first?["framesRead"] as? Int ?? 0) >= 1)
        let files = try #require(object["files"] as? [[String: Any]])
        #expect(files.map { $0["path"] as? String } == [master])
        #expect(files.first?["codec"] as? String == "ProRes 422 HQ")
        #expect(files.first?["hardware"] is Bool)
        let memory = try #require(object["memory"] as? [String: Any])
        #expect(memory["limit"] as? Int == Int(((ProcessInfo.processInfo.physicalMemory * 3 / 8) >> 20) << 20))
        let holders = try #require(memory["holders"] as? [String: [String: Int]])
        #expect(Set(holders.keys) == ["readers", "readAhead", "turns", "pictures", "frames", "sound"])
        #expect(memory["floor"] as? Int == holders.values.reduce(0) { $0 + ($1["floor"] ?? 0) })
    }

    @Test("render with --memory under the run's floor stops before the first frame, naming the limit and the floor")
    func refusesMemoryUnderFloor() throws {
        // Given
        let image = try picture(named: "frame.png")
        let document = try sut.write(
            #"{ "kind": "sequence", "format": { "size": [1280, 720], "fps": 10 }, "storyline": [ { "kind": "media", "media": "\#(image)", "duration": 0.3 } ] }"#,
            named: "doc.json"
        )
        let master = sut.directory.file("out.mov")

        // When
        let code = sut.run(["--memory", "8MB", "render", document, "-o", master, "--progress", "none"])

        // Then
        #expect(code == 1)
        #expect(sut.standardError == """
            frames: memory limit 8MB is under the 14.2 MB this run needs: readers 0 MB, readAhead 0 MB, turns 0 MB, \
            pictures 0 MB, frames 14.1 MB, sound 0.1 MB

            """)
        #expect(!FileManager.default.fileExists(atPath: master))
    }

    @Test("render --progress json writes one progress object a line on standard error, the last for the last frame")
    func writesJSONProgress() throws {
        // Given
        let document = try sut.write(sequence, named: "doc.json")
        let master = sut.directory.file("out.mov")

        // When
        let code = sut.run(["render", document, "-o", master, "--progress", "json"])

        // Then
        #expect(code == 0)
        let lines = sut.standardError.split(separator: "\n").map(String.init)
        let last = try #require(lines.last.flatMap { try JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] })
        #expect(lines.allSatisfy { $0.hasPrefix(#"{"progress": "0.1.0", "frame": "#) })
        #expect(last["frame"] as? Int == 15)
        #expect(last["frames"] as? Int == 15)
    }

    @Test("render --report to another extension, or to the output's file by another spelling, stops before the document is read", arguments: [
        ("run.txt", "a run's report is written to a .json file"),
        ("out.json", "the report would be written over a file the render writes")
    ])
    func stopsOnReport(
        name: String,
        reason: String
    ) throws {
        // Given
        let output = sut.directory.file("out.json")
        let report = sut.directory.file("./" + name)
        let missing = sut.directory.file("missing.json")

        // When
        let code = sut.run(["render", missing, "-o", output, "--report", report])

        // Then
        #expect(code == 1)
        #expect(sut.standardError == "frames: render: --report \"\(report)\": \(reason)\n")
    }

    // MARK: - Private
    private var sequence: String {
        #"""
        { "kind": "sequence", "format": { "size": [160, 90], "fps": 10 },
          "storyline": [
            { "kind": "solid", "color": "#000000", "duration": 1 },
            { "id": "end", "kind": "solid", "color": "#FFFFFF", "duration": 0.5, "transition": { "preset": "frames/fade", "seconds": 0.5 } }
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

//
//  ToolLibraryTests.swift
//  FramesTests
//
//  Created by JSilver on 11/25/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("ToolLibrary Tests")
struct ToolLibraryTests {
    // MARK: - Property
    private let directory: PackDirectory
    private let sut: ToolLibrary

    // MARK: - Initializer
    init() throws {
        directory = try PackDirectory()
        sut = ToolLibrary(packs: directory.packs)
        try directory.addPack("studio")
    }

    // MARK: - Test
    @Test("a tool is found by <pack>/<name>, with its description and the file its run names in its directory")
    func findsTool() throws {
        // Given
        let program = try addTool("autocut", manifest: #"{ "description": "cuts silence", "run": "autocut.py" }"#)

        // When
        let tool = try sut.tool(named: "studio/autocut")

        // Then
        #expect(tool == PackTool(name: "studio/autocut", description: "cuts silence", executable: program))
    }

    @Test(
        "a name that is not <pack>/<name>, a pack that is not there, and a tool the pack does not hold find nothing",
        arguments: ["autocut", "/abs/autocut", "studio/autocut/more", "nopack/autocut", "studio/captions"]
    )
    func findsNothing(name: String) throws {
        // Given
        try addTool("autocut", manifest: #"{ "description": "cuts silence", "run": "autocut.py" }"#)

        // When
        let tool = try sut.tool(named: name)

        // Then
        #expect(tool == nil)
    }

    @Test("a pack's tools are its directories under tools/, in name order, and a file there is no tool")
    func listsTools() throws {
        // Given
        let captions = try addTool("captions", manifest: #"{ "description": "places captions", "run": "captions" }"#)
        let autocut = try addTool("autocut", manifest: #"{ "description": "cuts silence", "run": "autocut.py" }"#)
        try directory.write("", in: "studio", at: "tools/notes.txt")
        let pack = try #require(try directory.packs.pack(named: "studio"))

        // When
        let tools = try sut.tools(in: pack)

        // Then
        #expect(tools == [
            PackTool(name: "studio/autocut", description: "cuts silence", executable: autocut),
            PackTool(name: "studio/captions", description: "places captions", executable: captions)
        ])
    }

    @Test(
        "a tool.json that misses a key, writes one as another type, holds another key, or runs no executable file of its directory stops",
        arguments: [
            (#"{ "run": "autocut.py" }"#, #"top level (tool): missing key "description""#),
            (#"{ "description": "cuts silence", "run": 1 }"#, "run (tool): expected a string, found 1"),
            (#"{ "description": "cuts silence", "run": "autocut.py", "version": "1.0.0" }"#, #"top level (tool): unknown key "version". Allowed: description, run"#),
            (#"{ "description": "cuts silence", "run": "../autocut.py" }"#, #"run (tool): "../autocut.py" is not the name of a file in the tool's directory"#),
            (#"{ "description": "cuts silence", "run": ".." }"#, #"run (tool): ".." is not the name of a file in the tool's directory"#),
            (#"{ "description": "cuts silence", "run": "missing.py" }"#, #"run (tool): "missing.py" is not an executable file in the tool's directory"#),
            (#"{ "description": "cuts silence", "run": "README.md" }"#, #"run (tool): "README.md" is not an executable file in the tool's directory"#)
        ]
    )
    func stopsOnManifest(
        manifest: String,
        message: String
    ) throws {
        // Given
        try addTool("autocut", manifest: manifest)
        try directory.write("", in: "studio", at: "tools/autocut/README.md")
        let file = directory.installed.appendingPathComponent("studio/tools/autocut/tool.json").path

        // When
        let error = #expect(throws: (any Error).self) { try sut.tool(named: "studio/autocut") }

        // Then
        #expect(error.map { "\($0)" } == "\(file): \(message)")
    }

    @Test("a tool directory without a tool.json stops, when it is named and when it is listed")
    func stopsOnMissingManifest() throws {
        // Given
        try FileManager.default.createDirectory(
            at: directory.installed.appendingPathComponent("studio/tools/autocut", isDirectory: true),
            withIntermediateDirectories: true
        )
        let pack = try #require(try directory.packs.pack(named: "studio"))
        let file = directory.installed.appendingPathComponent("studio/tools/autocut/tool.json").path

        // When
        let named = #expect(throws: PackError.self) { try sut.tool(named: "studio/autocut") }
        let listed = #expect(throws: PackError.self) { try sut.tools(in: pack) }

        // Then
        #expect(named?.description == "\(file): top level (tool): a tool holds a tool.json, and this one has none")
        #expect(listed == named)
    }

    @Test(
        "an unknown tool says what the name could be, by the name hint rule of presets",
        arguments: [
            ("studio/autocat", #"unknown tool "studio/autocat". Did you mean "studio/autocut"? The pack "studio" holds the tools studio/autocut, studio/captions"#),
            ("studio/render", #"unknown tool "studio/render". The pack "studio" holds the tools studio/autocut, studio/captions"#),
            ("nopack/autocut", #"unknown tool "nopack/autocut". A tool is named <pack>/<name>, and the ones frames ships are frames/<name>"#),
            ("/abs/autocut", #"unknown tool "/abs/autocut". A tool is named <pack>/<name>, and the ones frames ships are frames/<name>"#)
        ]
    )
    func describesUnknownTool(
        name: String,
        message: String
    ) throws {
        // Given
        try addTool("autocut", manifest: #"{ "description": "cuts silence", "run": "autocut.py" }"#)
        try addTool("captions", manifest: #"{ "description": "places captions", "run": "captions" }"#)

        // When
        let unknown = try sut.unknown(named: name)

        // Then
        #expect(unknown.description == message)
    }

    // MARK: - Private
    // A tool of the installed pack `studio` with its `tool.json`, and an executable program named by its `run` where
    // that is a plain name other than `missing.py` and `README.md`.
    @discardableResult
    private func addTool(
        _ name: String,
        manifest: String
    ) throws -> URL {
        let tool = directory.installed.appendingPathComponent("studio/tools/\(name)", isDirectory: true)
        try directory.write(manifest, to: tool.appendingPathComponent("tool.json"))

        let object = try JSONSerialization.jsonObject(with: Data(manifest.utf8)) as? [String: Any]
        let run = object?["run"] as? String ?? ""
        let program = tool.appendingPathComponent(run)
        guard !run.isEmpty, !run.contains("/"), run != "..", run != "missing.py", run != "README.md" else { return program }

        try directory.write("#!/bin/sh\nexit 0\n", to: program)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: program.path)

        return program
    }
}

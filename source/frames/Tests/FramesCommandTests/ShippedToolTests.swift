//
//  ShippedToolTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/25/26.
//

import Foundation
import FramesTestMedia
import Testing

@testable import Frames
@testable import FramesCommand

// The tools frames ships, read from the tool's own resource bundle as the tool reads them, with no pack installed
// beside them.
@Suite("ShippedTool Tests")
struct ShippedToolTests {
    // MARK: - Property
    private let directory: TemporaryDirectory
    private let packs: PackLibrary
    private let sut: ToolLibrary

    // MARK: - Initializer
    init() throws {
        directory = try TemporaryDirectory()
        packs = PackLibrary(
            installed: URL(fileURLWithPath: directory.file("installed"), isDirectory: true),
            shipped: CommandEnvironment.current.shippedPacks
        )
        sut = ToolLibrary(packs: packs)
    }

    // MARK: - Test
    @Test("the shipped pack holds frames/find-text and frames/track-motion, each with its description")
    func listsShippedTools() throws {
        // Given
        let pack = try #require(try packs.pack(named: "frames"))

        // When
        let tools = try sut.tools(in: pack)

        // Then
        #expect(tools.map(\.name) == ["frames/find-text", "frames/track-motion"])
        #expect(tools.map(\.description) == [
            "Fills each frames/find-text request, an area named by its text on screen, with the rectangle ocr finds for it",
            "Fills each frames/track-motion request, a clip's track, with the track data track prints for its target"
        ])
    }

    @Test("each shipped tool runs a program of its own name in its directory of the bundle, an executable file there", arguments: [
        "find-text", "track-motion"
    ])
    func findsShippedProgram(name: String) throws {
        // Given
        let directory = CommandEnvironment.current.shippedPacks.appendingPathComponent("frames/tools/\(name)", isDirectory: true)

        // When
        let tool = try #require(try sut.tool(named: "frames/\(name)"))

        // Then
        #expect(tool.executable.lastPathComponent == name)
        #expect(tool.executable.deletingLastPathComponent().standardizedFileURL.path == directory.standardizedFileURL.path)
        #expect(FileManager.default.isExecutableFile(atPath: tool.executable.path))
    }

    @Test("a tool name one character off a shipped tool is hinted with it and the tools the shipped pack holds")
    func hintsShippedTool() throws {
        // Given, When
        let unknown = try sut.unknown(named: "frames/find-txt")

        // Then
        #expect(unknown.description == #"unknown tool "frames/find-txt". Did you mean "frames/find-text"? The pack "frames" holds the tools frames/find-text, frames/track-motion"#)
    }

    // MARK: - Private
}

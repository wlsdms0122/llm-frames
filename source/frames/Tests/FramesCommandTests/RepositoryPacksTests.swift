//
//  RepositoryPacksTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Testing

@testable import FramesCommand

// The packs kept in the repository under `packs/`, installed by copying them into a temporary `FRAMES_HOME` beside
// the presets frames ships, as a user installs them.
@Suite("RepositoryPacks Tests")
struct RepositoryPacksTests {
    // MARK: - Property
    // This file is `source/frames/Tests/FramesCommandTests/` in the repository.
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    private static let packs = root.appendingPathComponent("packs", isDirectory: true)
    private static let builtInPresets = root.appendingPathComponent(
        "source/frames/Sources/FramesCommand/Resources/presets",
        isDirectory: true
    )

    private static let packNames = entries(in: packs)
    private static let themes = packNames.flatMap { pack in
        entries(in: packs.appendingPathComponent("\(pack)/themes", isDirectory: true))
            .filter { $0.hasSuffix(".json") }
            .map { "\(pack)/\(String($0.dropLast(".json".count)))" }
    }
    private static let filters = packNames.flatMap { pack in
        entries(in: packs.appendingPathComponent("\(pack)/presets/filter", isDirectory: true))
            .filter { $0.hasSuffix(".json") }
            .map { "\(pack)/\(String($0.dropLast(".json".count)))" }
    }

    // A sequence that needs no media, so a theme is merged and checked without reading anything else.
    private static let solid = #"""
        { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [ { "solid": "#000000", "duration": 1 } ] }
        """#

    private let sut: TestShell

    // MARK: - Initializer
    init() throws {
        sut = try TestShell()
        try copy(Self.builtInPresets, into: sut.builtIn)
        for pack in Self.packNames {
            try FileManager.default.copyItem(
                at: Self.packs.appendingPathComponent(pack, isDirectory: true),
                to: sut.installed.appendingPathComponent(pack, isDirectory: true)
            )
        }
    }

    // MARK: - Test
    @Test("the repository keeps the three first forms and the film looks as packs")
    func holdsPacks() {
        // Given
        let expected = ["demo", "film", "pr-evidence", "shorts"]

        // When
        let packs = Self.packNames

        // Then
        #expect(packs == expected)
    }

    @Test("packs lists every installed pack with the name, version 1.0.0 and description its pack.json gives")
    func listsPacks() {
        // Given
        let expected: [[String?]] = Self.packNames.map { [$0, "1.0.0"] }

        // When
        let code = sut.run(["packs"])
        let fields = sut.standardOutput.split(separator: "\n").map { $0.components(separatedBy: "  ") }

        // Then
        #expect(code == 0, "\(sut.standardError)")
        #expect(fields.map { [$0.first, $0.dropFirst(2).first] } == expected)
        #expect(fields.allSatisfy { $0.count == 4 && !$0.contains("-") })
    }

    @Test("packs <pack> lists what the pack holds, every preset in it read and checked", arguments: packNames)
    func listsPackContents(_ pack: String) {
        // Given
        let head = "\(pack)  "

        // When
        let code = sut.run(["packs", pack])

        // Then
        #expect(code == 0, "\(sut.standardError)")
        #expect(sut.standardOutput.hasPrefix(head))
    }

    @Test("every theme a pack holds merges on the base theme, its default presets found", arguments: themes)
    func mergesTheme(_ theme: String) {
        // Given
        let arguments = ["--theme", theme, "timeline", "-"]

        // When
        let code = sut.run(arguments, input: Self.solid)

        // Then
        #expect(code == 0, "\(sut.standardError)")
    }

    @Test("every filter a pack holds resolves on an adjustment clip, the LUTs it names read", arguments: filters)
    func resolvesFilter(_ filter: String) {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [1080, 1920] },
              "storyline": [ { "solid": "#000000", "duration": 1 } ],
              "clips": [ { "adjust": "\#(filter)", "at": [0, 1] } ] }
            """#

        // When
        let code = sut.run(["resolve", "-", "-o", sut.directory.file("resolved.json")], input: document)

        // Then
        #expect(code == 0, "\(sut.standardError)")
    }

    // MARK: - Private
    // What a directory holds, in name order, without hidden files.
    private static func entries(in directory: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []

        return names.filter { !$0.hasPrefix(".") }.sorted()
    }

    // Copies every preset frames ships over the ones the shell starts with, kind by kind.
    private func copy(
        _ presets: URL,
        into builtIn: URL
    ) throws {
        for kind in Self.entries(in: presets) {
            let folder = builtIn.appendingPathComponent(kind, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for file in Self.entries(in: presets.appendingPathComponent(kind, isDirectory: true)) {
                let target = folder.appendingPathComponent(file)
                if FileManager.default.fileExists(atPath: target.path) {
                    try FileManager.default.removeItem(at: target)
                }
                try FileManager.default.copyItem(at: presets.appendingPathComponent("\(kind)/\(file)"), to: target)
            }
        }
    }
}

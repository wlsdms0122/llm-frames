//
//  PackLibraryTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("PackLibrary Tests")
struct PackLibraryTests {
    // MARK: - Property
    private let directory: PackDirectory

    // MARK: - Initializer
    init() throws {
        directory = try PackDirectory()
    }

    // MARK: - Test
    @Test("an installed pack is found by the name of its directory, whatever its manifest calls it")
    func findsInstalledPack() throws {
        // Given
        let packDirectory = try directory.addPack("shorts")
        let sut = directory.packs

        // When
        let pack = try sut.pack(named: "shorts")

        // Then
        #expect(pack?.name == "shorts")
        #expect(pack?.directory.path == packDirectory.path)
        #expect(pack?.manifest.name == "A pack for tests")
    }

    @Test("a pack that ships with frames is found as if installed")
    func findsShippedPack() throws {
        // Given
        let packDirectory = try directory.addPack("frames", in: directory.shipped)
        let sut = directory.packs

        // When
        let pack = try sut.pack(named: "frames")

        // Then
        #expect(pack?.directory.path == packDirectory.path)
    }

    @Test("an installed pack of the same name as a shipped one stops")
    func refusesDuplicatePack() throws {
        // Given
        try directory.addPack("shorts")
        try directory.addPack("shorts", in: directory.shipped)
        let sut = directory.packs

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.pack(named: "shorts") }
        let manifest = directory.installed.appendingPathComponent("shorts/pack.json").path
        let shipped = directory.shipped.appendingPathComponent("shorts").path
        #expect(error?.description == #"\#(manifest): top level (manifest): a pack named "shorts" ships with frames at \#(shipped), so an installed one of that name stops. Rename or remove the installed one"#)
    }

    @Test("a pack directory without a pack.json stops")
    func refusesMissingManifest() throws {
        // Given
        try FileManager.default.createDirectory(
            at: directory.installed.appendingPathComponent("loose", isDirectory: true),
            withIntermediateDirectories: true
        )
        let sut = directory.packs

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.pack(named: "loose") }
        let manifest = directory.installed.appendingPathComponent("loose/pack.json").path
        #expect(error?.description == "\(manifest): top level (manifest): a pack holds a pack.json, and this one has none")
    }

    @Test("a pack written for other versions of frames stops, naming both")
    func refusesEngineOutOfRange() throws {
        // Given
        try directory.addPack("future", engine: "^2.1")
        let sut = directory.packs

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.pack(named: "future") }
        let manifest = directory.installed.appendingPathComponent("future/pack.json").path
        #expect(error?.description == #"\#(manifest): engine (manifest): pack "future" is written for frames ^2.1, and this is frames 1.0.0"#)
    }

    @Test("a pack that is not there is none")
    func findsNoUnknownPack() throws {
        // Given
        let sut = directory.packs

        // When
        let pack = try sut.pack(named: "missing")

        // Then
        #expect(pack == nil)
    }

    @Test("installed packs live at $FRAMES_HOME/packs, and FRAMES_HOME defaults to ~/.config/frames")
    func findsFramesHome() throws {
        // Given
        let home = directory.root.appendingPathComponent("home", isDirectory: true)
        let framesHome = home.appendingPathComponent(".config/frames", isDirectory: true)
        try directory.addPack("shorts", in: framesHome.appendingPathComponent("packs", isDirectory: true))
        let byDefault = PackLibrary(environment: ["HOME": home.path], shipped: directory.shipped)
        let bySetting = PackLibrary(environment: ["HOME": "/nowhere", "FRAMES_HOME": framesHome.path], shipped: directory.shipped)

        // When
        let defaultPack = try byDefault.pack(named: "shorts")
        let settingPack = try bySetting.pack(named: "shorts")

        // Then
        #expect(defaultPack?.directory.standardizedFileURL.path == framesHome.appendingPathComponent("packs/shorts").path)
        #expect(settingPack?.directory.standardizedFileURL.path == framesHome.appendingPathComponent("packs/shorts").path)
    }

    @Test("every installed and shipped pack is listed in name order, and a hidden entry is no pack")
    func listsPacks() throws {
        // Given
        try directory.addPack("shorts")
        try directory.addPack("demo", in: directory.shipped)
        try directory.write("", to: directory.installed.appendingPathComponent(".DS_Store"))
        try directory.write("", to: directory.shipped.appendingPathComponent(".gitkeep"))
        let sut = directory.packs

        // When
        let packs = try sut.packs()

        // Then
        #expect(packs.map(\.name) == ["demo", "shorts"])
    }

    @Test("a pack's folder lists its names in order, without the extension its kind takes and without hidden files")
    func listsFolderNames() throws {
        // Given
        try directory.addPack("shorts")
        try directory.write("{}", in: "shorts", at: "themes/warm.json")
        try directory.write("{}", in: "shorts", at: "themes/cool.json")
        try directory.write("notes", in: "shorts", at: "themes/README.md")
        try directory.write("", in: "shorts", at: "themes/.gitkeep")
        try directory.write("", in: "shorts", at: "media/leak.mov")
        let sut = directory.packs
        let pack = try #require(try sut.pack(named: "shorts"))

        // When
        let themes = try sut.names(in: "themes", of: pack, pathExtension: "json")
        let media = try sut.names(in: "media", of: pack, pathExtension: nil)
        let luts = try sut.names(in: "luts", of: pack, pathExtension: "cube")

        // Then
        #expect(themes == ["cool", "warm"])
        #expect(media == ["leak.mov"])
        #expect(luts.isEmpty)
    }

    @Test(
        "a name is an absolute path or <pack>/<name>, and any other spelling, a bare name too, names nothing",
        arguments: [
            ("/abs/theme.json", PackReference.path("/abs/theme.json")),
            ("shorts/shorts", .pack(pack: "shorts", name: "shorts")),
            ("pop", nil),
            ("a/b/c", nil),
            ("shorts/", nil),
            ("../shorts", nil),
            ("shorts/..", nil),
            ("./x", nil),
            ("", nil)
        ]
    )
    func spellsNames(name: String, reference: PackReference?) {
        // Given, When
        let sut = PackReference(name)

        // Then
        #expect(sut == reference)
    }
}

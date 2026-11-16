//
//  PresetValueResolverTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("PresetValueResolver Tests")
struct PresetValueResolverTests {
    // MARK: - Property
    private let directory: PackDirectory

    // MARK: - Initializer
    init() throws {
        directory = try PackDirectory()
        // The base theme names `pop` for labels, so it must be built in.
        try directory.write(
            #"{ "description": "pops", "entrance": { "seconds": 0.3, "keys": [] } }"#,
            to: directory.builtIn.appendingPathComponent("animation/pop.json")
        )
        try directory.addPack("shorts")
        try directory.write(
            #"{ "description": "film", "ops": [ { "op": "lut", "file": "shorts/film", "amount": 1 } ] }"#,
            in: "shorts",
            at: "presets/filter/film.json"
        )
        try directory.write(
            #"{ "description": "wipe", "seconds": 1, "matte": { "media": "shorts/wipe.png" } }"#,
            in: "shorts",
            at: "presets/transition/wipe.json"
        )
        try directory.write(
            #"{ "description": "stinger", "seconds": 1, "cover": { "media": "/abs/stinger.mov", "keys": [] } }"#,
            in: "shorts",
            at: "presets/transition/stinger.json"
        )
        try directory.write(
            #"{ "description": "loose", "seconds": 1, "matte": { "media": "wipe.png" } }"#,
            in: "shorts",
            at: "presets/transition/loose.json"
        )
    }

    // MARK: - Test
    @Test("a pack preset's LUT and matte named by <pack>/<name> are pinned in that pack's folders")
    func pinsPackFiles() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence",
              "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 2, "filter": "shorts/film" },
                             { "media": "/abs/run.mp4", "in": 2, "out": 4, "transition": "shorts/wipe" } ] }
            """#)
        let pack = directory.installed.appendingPathComponent("shorts", isDirectory: true)

        // When
        let resolved = try ResolvedDocumentWriter(hashes: FileHashTable()).document(planner().plan(document))

        // Then
        let storyline = resolved.objectValue?["storyline"]?.arrayValue ?? []
        let lut = storyline.first?.objectValue?["filter"]?.arrayValue?.first?.objectValue
        let matte = storyline.last?.objectValue?["transition"]?.objectValue?["matte"]?.objectValue
        #expect(lut?["file"] == .string(pack.appendingPathComponent("luts/film.cube").standardizedFileURL.path))
        #expect(matte?["file"] == .string(pack.appendingPathComponent("media/wipe.png").standardizedFileURL.path))
    }

    @Test("a cover named by an absolute path in a pack preset keeps that path")
    func keepsAbsolutePath() throws {
        // Given
        let sut = PresetValueResolver(library: directory.library())
        let preset = try #require(try presets().transition(named: "shorts/stinger"))

        // When
        let resolved = try sut.transition(preset, place: .root, kind: .clip(.media(.video)))

        // Then
        #expect(resolved.cover?.source == .media("/abs/stinger.mov"))
    }

    @Test("a matte named by a bare name names no file and stops")
    func stopsOnBareName() throws {
        // Given
        let sut = PresetValueResolver(library: directory.library())
        let preset = try #require(try presets().transition(named: "shorts/loose"))

        // When
        let error = #expect(throws: ResolveError.self) {
            try sut.transition(preset, place: .root, kind: .clip(.media(.video)))
        }

        // Then
        #expect(error == .unknownPresetFile(place: .root, kind: .clip(.media(.video)), name: "wipe.png"))
    }

    // MARK: - Private
    private func presets() -> PresetLibrary {
        PresetLibrary(builtIn: directory.builtIn, packs: directory.packs)
    }

    private func planner() -> DocumentPlanner {
        let library = directory.library()

        return DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: presets(),
            ocr: Fixture.ocr,
            tracker: Fixture.tracker,
            shaper: Fixture.shaper,
            library: library
        )
    }
}

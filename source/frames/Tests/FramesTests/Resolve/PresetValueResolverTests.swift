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
        // The base theme names `frames/pop` for labels, so the shipped `frames` pack must hold it.
        try directory.addPack("frames", in: directory.shipped)
        try directory.write(
            #"{ "description": "pops", "entrance": { "seconds": 0.3, "keys": [] } }"#,
            to: directory.shipped.appendingPathComponent("frames/presets/animation/pop.json")
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
        let resolved = ResolvedDocumentWriter().document(try ResolvedDocument(plan: planner().plan(document), hashes: FileHashTable()))

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
        let resolved = try sut.transition(preset, theme: .base, place: .root, kind: .clip(.media(.video)))

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
            try sut.transition(preset, theme: .base, place: .root, kind: .clip(.media(.video)))
        }

        // Then
        #expect(error == .unknownPresetFile(place: .root, kind: .clip(.media(.video)), name: "wipe.png"))
    }

    @Test("a cover colour named in a preset is written as the theme's value, #RRGGBBAA")
    func resolvesCoverColor() throws {
        // Given
        let sut = PresetValueResolver(library: directory.library())
        let preset = TransitionPreset(
            description: "",
            seconds: 1,
            over: .incoming,
            incoming: nil,
            outgoing: nil,
            cover: Cover(source: .color("accent"), span: Span(ease: .linear, keys: [])),
            matte: nil
        )

        // When
        let resolved = try sut.transition(preset, theme: .base, place: .root, kind: .clip(.media(.video)))

        // Then
        #expect(resolved.cover?.source == .color("#ED2929FF"))
    }

    @Test(
        "a bloom colour is written as #RRGGBBAA, a theme colour by its value",
        arguments: [("emphasis", "#FFD43BFF"), ("#ffffff", "#FFFFFFFF"), ("#00000080", "#00000080")]
    )
    func resolvesBloomColor(
        written: String,
        resolved: String
    ) throws {
        // Given
        let sut = PresetValueResolver(library: directory.library())

        // When
        let operation = try sut.operation(
            .bloom(amount: 0.5, radius: 4, color: written),
            theme: .base,
            place: .root,
            kind: .clip(.media(.video))
        )

        // Then
        #expect(operation == .bloom(amount: 0.5, radius: 4, color: resolved))
    }

    @Test("a colour a preset names that the theme does not hold stops")
    func stopsOnUnknownColor() throws {
        // Given
        let sut = PresetValueResolver(library: directory.library())

        // When
        let error = #expect(throws: ResolveError.self) {
            try sut.operation(.bloom(amount: 0.5, radius: 4, color: "glow"), theme: .base, place: .root, kind: .clip(.media(.video)))
        }

        // Then
        #expect(error == .unknownPresetColor(place: .root, kind: .clip(.media(.video)), name: "glow"))
    }

    // MARK: - Private
    private func presets() -> PresetLibrary {
        PresetLibrary(packs: directory.packs)
    }

    // The pack's matte is probed as any other media.
    private func planner() -> DocumentPlanner {
        let wipe = directory.installed.appendingPathComponent("shorts/media/wipe.png").standardizedFileURL.path
        let mediaFacts = MediaFactTable(
            files: Fixture.mediaFacts.files.merging([wipe: ProbedMedia(kind: .image, size: Size(width: 1080, height: 1920))]) { $1 },
            imageSequences: Fixture.mediaFacts.imageSequences
        )
        let library = directory.library(mediaFacts: mediaFacts)

        return DocumentPlanner(
            mediaFacts: mediaFacts,
            presets: presets(),
            ocr: Fixture.ocr,
            tracker: Fixture.tracker,
            shaper: Fixture.shaper,
            library: library
        )
    }
}

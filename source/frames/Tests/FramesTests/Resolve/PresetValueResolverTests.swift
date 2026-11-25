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
        try directory.addPack("shorts")
        try directory.write(
            #"{ "description": "film", "ops": [ { "op": "lut", "file": "shorts/film", "amount": 1 } ] }"#,
            in: "shorts",
            at: "presets/filter/film.json"
        )
        try directory.write(
            #"""
            { "description": "ripple", "ops": [ { "op": "displace", "file": "shorts/ripple.png", "amount": 8 },
                                                { "op": "displace", "file": "/abs/matte.png", "amount": 4, "offset": [2, -2] } ] }
            """#,
            in: "shorts",
            at: "presets/filter/ripple.json"
        )
        try directory.write(
            #"""
            { "description": "room", "params": { "wet": { "type": "number", "default": -6, "description": "the level" } },
              "ops": [ { "op": "convolve", "file": "shorts/hall.wav", "gain": { "param": "wet" } },
                       { "op": "convolve", "file": "/abs/ding.wav" } ] }
            """#,
            in: "shorts",
            at: "presets/audio/room.json"
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
            #"""
            { "description": "deck", "seconds": 1, "cover": { "media": { "file": "shorts/deck.pdf", "page": 2 } },
              "matte": { "media": { "file": "/abs/logo.pdf", "page": 1 } } }
            """#,
            in: "shorts",
            at: "presets/transition/deck.json"
        )
        try directory.write(
            #"{ "description": "zero", "seconds": 1, "matte": { "media": { "file": "/abs/logo.pdf", "page": 0 } } }"#,
            in: "shorts",
            at: "presets/transition/zero.json"
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
        let resolved = ResolvedDocumentWriter().document(try ResolvedSequence(plan: planner().plan(document), hashes: FileHashTable()))

        // Then
        let storyline = resolved.objectValue?["storyline"]?.arrayValue ?? []
        let entry = storyline.first?.objectValue?["filter"]?.arrayValue?.first?.objectValue
        let lut = entry?["ops"]?.arrayValue?.first?.objectValue
        let matte = storyline.last?.objectValue?["transition"]?.objectValue?["matte"]?.objectValue
        #expect(lut?["file"] == .string(pack.appendingPathComponent("luts/film.cube").standardizedFileURL.path))
        #expect(matte?["file"] == .string(pack.appendingPathComponent("media/wipe.png").standardizedFileURL.path))
    }

    @Test("a pack preset's displacement maps, by <pack>/<name.ext> in the pack's media and by an absolute path, are pinned with their SHA-256")
    func pinsDisplacementMaps() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 2, "filter": "shorts/ripple" } ] }
            """#)
        let ripple = directory.installed.appendingPathComponent("shorts/media/ripple.png").standardizedFileURL.path

        // When
        let resolved = ResolvedDocumentWriter().document(
            try ResolvedSequence(plan: planner().plan(document), hashes: FileHashTable([ripple: "ripple-digest"]))
        )

        // Then
        let entry = resolved.objectValue?["storyline"]?.arrayValue?.first?.objectValue?["filter"]?.arrayValue?.first?.objectValue
        let operations = (entry?["ops"]?.arrayValue ?? []).compactMap(\.objectValue)
        #expect(operations.map { $0["file"] } == [.string(ripple), .string("/abs/matte.png")])
        #expect(operations.map { $0["sha256"] } == [.string("ripple-digest"), .string("sha256-of-/abs/matte.png")])
    }

    @Test(
        "a displacement map that is no raster still read as its tags say stops, naming where it is chosen",
        arguments: [
            ("/abs/run.mp4", DisplacementMapRefusal.video),
            ("/abs/frames", .imageSequence),
            ("/abs/logo.pdf", .page),
            ("/abs/edit.json", .sequence),
            ("/abs/bgm.m4a", .sound),
            ("/abs/icc.png", .unconvertibleColor)
        ]
    )
    func refusesDisplacementMap(
        reference: String,
        refusal: DisplacementMapRefusal
    ) throws {
        // Given
        let icc = ProbedColorSpace(
            conversion: nil,
            primaries: nil,
            transfer: nil,
            matrix: nil,
            bitDepth: 8,
            isHighDynamicRange: false
        )
        let mediaFacts = MediaFactTable(
            files: Fixture.mediaFacts.files.merging(["/abs/icc.png": ProbedMedia(kind: .image, colorSpace: icc)]) { $1 },
            imageSequences: Fixture.mediaFacts.imageSequences,
            pages: Fixture.pages
        )
        let sut = PresetValueResolver(library: directory.library(mediaFacts: mediaFacts))
        let place = Place.root.appending(key: "filter")

        // When
        let error = #expect(throws: ResolveError.self) {
            try sut.displacementMap(reference, place: place, kind: .clip(.media(.video)))
        }

        // Then
        #expect(error == .unusableDisplacementMap(place: place, kind: .clip(.media(.video)), reference: reference, refusal: refusal))
    }

    @Test("a displacement map that is not there, or named by a bare name, stops")
    func refusesMissingDisplacementMap() throws {
        // Given
        let sut = PresetValueResolver(library: directory.library())

        // When
        let missing = #expect(throws: ResolveError.self) {
            try sut.displacementMap("/abs/none.png", place: .root, kind: .clip(.media(.video)))
        }
        let bare = #expect(throws: ResolveError.self) {
            try sut.displacementMap("ripple.png", place: .root, kind: .clip(.media(.video)))
        }

        // Then
        #expect(missing == .missingMedia(place: .root, kind: .clip(.media(.video)), reference: "/abs/none.png"))
        #expect(bare == .unknownPresetFile(place: .root, kind: .clip(.media(.video)), name: "ripple.png"))
    }

    @Test("a pack preset's impulse responses, by <pack>/<name.ext> in the pack's media and by an absolute path, are pinned with their SHA-256")
    func pinsImpulseResponses() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 2 } ],
              "clips": [ { "media": "/abs/bgm.m4a", "audioFilter": "shorts/room" } ] }
            """#)
        let hall = directory.installed.appendingPathComponent("shorts/media/hall.wav").standardizedFileURL.path

        // When
        let resolved = ResolvedDocumentWriter().document(
            try ResolvedSequence(plan: planner().plan(document), hashes: FileHashTable([hall: "hall-digest"]))
        )

        // Then
        let sound = resolved.objectValue?["audio"]?.arrayValue?.last?.objectValue
        let entry = sound?["audioFilter"]?.arrayValue?.first?.objectValue
        let operations = (entry?["ops"]?.arrayValue ?? []).compactMap(\.objectValue)
        #expect(operations.map { $0["op"] } == [.string("convolve"), .string("convolve")])
        #expect(operations.map { $0["file"] } == [.string(hall), .string("/abs/ding.wav")])
        #expect(operations.map { $0["sha256"] } == [.string("hall-digest"), .string("sha256-of-/abs/ding.wav")])
        #expect(operations.allSatisfy { $0["gain"] != nil })
    }

    @Test(
        "an impulse response that is no sound an impulse response can be stops, naming where it is chosen",
        arguments: [
            ("/abs/card.png", ImpulseResponseRefusal.noSound),
            ("/abs/short.mp4", .noSound),
            ("/abs/frames", .imageSequence),
            ("/abs/logo.pdf", .page),
            ("/abs/edit.json", .sequence),
            ("/abs/silence.wav", .noSamples),
            ("/abs/long.wav", .tooLong(duration: 31))
        ]
    )
    func refusesImpulseResponse(
        reference: String,
        refusal: ImpulseResponseRefusal
    ) throws {
        // Given
        let sut = PresetValueResolver(library: directory.library(mediaFacts: impulseResponseFacts()))
        let place = Place.root.appending(key: "audioFilter")

        // When
        let error = #expect(throws: ResolveError.self) {
            try sut.impulseResponse(reference, place: place, kind: .clip(.media(.audio)))
        }

        // Then
        #expect(error == .unusableImpulseResponse(place: place, kind: .clip(.media(.audio)), reference: reference, refusal: refusal))
    }

    @Test("an impulse response of exactly 30 seconds is taken as its path")
    func takesLongestImpulseResponse() throws {
        // Given
        let sut = PresetValueResolver(library: directory.library(mediaFacts: impulseResponseFacts()))

        // When
        let path = try sut.impulseResponse("/abs/hall.wav", place: .root, kind: .clip(.media(.audio)))

        // Then
        #expect(path == "/abs/hall.wav")
    }

    @Test("an impulse response that is not there, or in a pack that is not installed, stops")
    func refusesMissingImpulseResponse() throws {
        // Given
        let sut = PresetValueResolver(library: directory.library())

        // When
        let missing = #expect(throws: ResolveError.self) {
            try sut.impulseResponse("/abs/none.wav", place: .root, kind: .clip(.media(.audio)))
        }
        let unknownPack = #expect(throws: ResolveError.self) {
            try sut.impulseResponse("nopack/hall.wav", place: .root, kind: .clip(.media(.audio)))
        }

        // Then
        #expect(missing == .missingMedia(place: .root, kind: .clip(.media(.audio)), reference: "/abs/none.wav"))
        #expect(unknownPack == .unknownPresetFile(place: .root, kind: .clip(.media(.audio)), name: "nopack/hall.wav"))
    }

    @Test("a cover named by an absolute path in a pack preset keeps that path")
    func keepsAbsolutePath() throws {
        // Given
        let sut = PresetValueResolver(library: directory.library())
        let preset = try #require(try presets().transition(PresetInstance(name: "shorts/stinger")))

        // When
        let resolved = try sut.transition(preset, theme: .base, place: .root, kind: .clip(.media(.video)))

        // Then
        #expect(resolved.cover?.source == .media("/abs/stinger.mov"))
    }

    @Test("a cover and a matte take a page of a PDF as {file, page}, its file found as any preset file is")
    func readsPageMedia() throws {
        // Given
        let sut = PresetValueResolver(library: directory.library())
        let preset = try #require(try presets().transition(PresetInstance(name: "shorts/deck")))
        let deck = directory.installed.appendingPathComponent("shorts/media/deck.pdf").standardizedFileURL.path

        // When
        let resolved = try sut.transition(preset, theme: .base, place: .root, kind: .clip(.media(.video)))

        // Then
        #expect(resolved.cover?.source == .page(deck, page: 2))
        #expect(resolved.matte?.media == "/abs/logo.pdf")
        #expect(resolved.matte?.page == 1)
    }

    @Test("a cover's or a matte's page that is not a whole number from 1 stops at the key check")
    func refusesPageBelowOne() {
        // When
        let error = #expect(throws: (any Error).self) { try presets().transition(PresetInstance(name: "shorts/zero")) }

        // Then
        #expect("\(error.map { "\($0)" } ?? "")".contains("matte.media.page"))
    }

    @Test("a matte named by a bare name names no file and stops")
    func stopsOnBareName() throws {
        // Given
        let sut = PresetValueResolver(library: directory.library())
        let preset = try #require(try presets().transition(PresetInstance(name: "shorts/loose")))

        // When
        let error = #expect(throws: ResolveError.self) {
            try sut.transition(preset, theme: .base, place: .root, kind: .clip(.media(.video)))
        }

        // Then
        #expect(error == .unknownPresetFile(place: .root, kind: .clip(.media(.video)), name: "wipe.png"))
    }

    @Test("a cover colour named in a preset is written as the theme's value, color(srgb r g b / a)")
    func resolvesCoverColor() throws {
        // Given
        let sut = PresetValueResolver(library: directory.library())
        let preset = TransitionPreset(
            description: "",
            seconds: 1,
            over: .incoming,
            audio: .constantPower,
            incoming: nil,
            outgoing: nil,
            cover: Cover(source: .color("shadow"), span: Span(ease: .linear, keys: [])),
            matte: nil
        )

        // When
        let resolved = try sut.transition(preset, theme: .base, place: .root, kind: .clip(.media(.video)))

        // Then
        #expect(resolved.cover?.source == .color("color(srgb 0 0 0 / 0.5019607843137255)"))
    }

    @Test(
        "a bloom colour is written as color(srgb r g b / a), a theme colour by its value",
        arguments: [
            ("shadow", "color(srgb 0 0 0 / 0.5019607843137255)"),
            ("#ffffff", "color(srgb 1 1 1 / 1)"),
            ("color(srgb 0.5 0.25 2 / 0.5)", "color(srgb 0.5 0.25 2 / 0.5)")
        ]
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

    // `/abs/silence.wav` is sound of no length, `/abs/long.wav` of 31 seconds and `/abs/hall.wav` of 30.
    private func impulseResponseFacts() -> MediaFactTable {
        let sound = { (duration: Double) in
            ProbedMedia(kind: .audio, duration: duration, sound: ProbedSound(channels: 2, sampleRate: 48000))
        }

        return MediaFactTable(
            files: Fixture.mediaFacts.files.merging([
                "/abs/silence.wav": sound(0),
                "/abs/long.wav": sound(31),
                "/abs/hall.wav": sound(30)
            ]) { $1 },
            imageSequences: Fixture.mediaFacts.imageSequences,
            pages: Fixture.pages
        )
    }

    // The pack's matte, displacement map and impulse response are probed as any other media.
    private func planner() -> DocumentPlanner {
        let wipe = directory.installed.appendingPathComponent("shorts/media/wipe.png").standardizedFileURL.path
        let ripple = directory.installed.appendingPathComponent("shorts/media/ripple.png").standardizedFileURL.path
        let hall = directory.installed.appendingPathComponent("shorts/media/hall.wav").standardizedFileURL.path
        let still = ProbedMedia(kind: .image, size: Size(width: 1080, height: 1920))
        let room = ProbedMedia(kind: .audio, duration: 2, sound: ProbedSound(channels: 2, sampleRate: 48000))
        let mediaFacts = MediaFactTable(
            files: Fixture.mediaFacts.files.merging([wipe: still, ripple: still, hall: room]) { $1 },
            imageSequences: Fixture.mediaFacts.imageSequences
        )
        let library = directory.library(mediaFacts: mediaFacts)

        return DocumentPlanner(
            mediaFacts: mediaFacts,
            presets: presets(),
            shaper: Fixture.shaper,
            library: library
        )
    }
}

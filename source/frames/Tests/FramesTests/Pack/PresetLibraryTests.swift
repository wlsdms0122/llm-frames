//
//  PresetLibraryTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("PresetLibrary Tests")
struct PresetLibraryTests {
    // MARK: - Property
    private let directory: PackDirectory
    private let sut: PresetLibrary

    // MARK: - Initializer
    init() throws {
        directory = try PackDirectory()
        sut = PresetLibrary(builtIn: directory.builtIn, packs: directory.packs)
    }

    // MARK: - Test
    @Test("a bare name is a built in preset, laid out as a pack's presets")
    func findsBuiltInPreset() throws {
        // Given
        try directory.write(
            #"{ "description": "a flash", "seconds": 0.4 }"#,
            to: directory.builtIn.appendingPathComponent("transition/flash.json")
        )

        // When
        let preset = try sut.transition(named: "flash")

        // Then
        #expect(preset?.seconds == 0.4)
    }

    @Test("<pack>/<name> is a preset in that pack's presets, and an absolute path reads that file")
    func findsPackAndPathPresets() throws {
        // Given
        try directory.addPack("shorts")
        try directory.write(#"{ "description": "pops", "entrance": { "seconds": 0.3, "keys": [] } }"#, in: "shorts", at: "presets/animation/pop.json")
        let file = try directory.write(#"{ "description": "warm", "ops": [] }"#, in: "loose", at: "warm.json")

        // When
        let animation = try sut.animation(named: "shorts/pop")
        let filter = try sut.filter(named: file.path)

        // Then
        #expect(animation?.entrance?.length == 0.3)
        #expect(filter?.description == "warm")
    }

    @Test("a preset that is not there, or in a pack that is not there, is none", arguments: ["flash", "shorts/flash", "nopack/flash", "/abs/flash.json", "a/b/c"])
    func findsNoMissingPreset(name: String) throws {
        // Given
        try directory.addPack("shorts")

        // When
        let preset = try sut.transition(named: name)

        // Then
        #expect(preset == nil)
    }

    @Test("an error in a preset file names the preset as it was referred to")
    func namesPresetFile() throws {
        // Given
        try directory.addPack("shorts")
        try directory.write(#"{ "description": "x" }"#, in: "shorts", at: "presets/transition/flash.json")

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.transition(named: "shorts/flash") }
        #expect(error?.description == #"shorts/flash: top level (transition): missing key "seconds""#)
    }

    @Test("a kind lists the built in presets first and then each pack's, with their descriptions, hidden files skipped")
    func listsPresets() throws {
        // Given
        try directory.write(#"{ "description": "a flash", "seconds": 0.4 }"#, to: directory.builtIn.appendingPathComponent("transition/flash.json"))
        try directory.write("", to: directory.builtIn.appendingPathComponent("transition/.gitkeep"))
        try directory.addPack("shorts")
        try directory.write(#"{ "description": "pushes up", "seconds": 0.3 }"#, in: "shorts", at: "presets/transition/push-up.json")
        try directory.write(#"{ "description": "pops", "entrance": { "seconds": 0.3, "keys": [] } }"#, in: "shorts", at: "presets/animation/pop.json")

        // When
        let transitions = try sut.presets(of: .transition)
        let animations = try sut.presets(of: .animation)

        // Then
        #expect(transitions == [
            PresetEntry(kind: .transition, name: "flash", description: "a flash"),
            PresetEntry(kind: .transition, name: "shorts/push-up", description: "pushes up")
        ])
        #expect(animations == [PresetEntry(kind: .animation, name: "shorts/pop", description: "pops")])
    }

    @Test("a preset that would stop a document stops the listing, named as a document names it")
    func stopsListingOnBrokenPreset() throws {
        // Given
        try directory.addPack("shorts")
        try directory.write(#"{ "description": "x" }"#, in: "shorts", at: "presets/transition/flash.json")

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.presets(of: .transition) }
        #expect(error?.description == #"shorts/flash: top level (transition): missing key "seconds""#)
    }

    @Test("one pack lists only its own presets of a kind")
    func listsPackPresets() throws {
        // Given
        try directory.write(#"{ "description": "a flash", "seconds": 0.4 }"#, to: directory.builtIn.appendingPathComponent("transition/flash.json"))
        try directory.addPack("shorts")
        try directory.write(#"{ "description": "pushes up", "seconds": 0.3 }"#, in: "shorts", at: "presets/transition/push-up.json")
        let pack = try #require(try directory.packs.pack(named: "shorts"))

        // When
        let presets = try sut.presets(of: .transition, in: pack)

        // Then
        #expect(presets.map(\.name) == ["shorts/push-up"])
    }

    @Test("a preset's text is its file as written, by any name a document gives it, and none when it is not there")
    func readsPresetText() throws {
        // Given
        let text = "{\n  \"description\": \"a flash\",   \"seconds\": 0.4\n}\n"
        try directory.write(text, to: directory.builtIn.appendingPathComponent("transition/flash.json"))
        try directory.addPack("shorts")
        let packed = try directory.write(text, in: "shorts", at: "presets/transition/flash.json")

        // When
        let builtIn = try sut.text(named: "flash", kind: .transition)
        let pack = try sut.text(named: "shorts/flash", kind: .transition)
        let path = try sut.text(named: packed.path, kind: .transition)
        let missing = try sut.text(named: "flash", kind: .animation)

        // Then
        #expect(builtIn == text)
        #expect(pack == text)
        #expect(path == text)
        #expect(missing == nil)
    }
}

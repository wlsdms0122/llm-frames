//
//  PresetLibraryTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

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
}

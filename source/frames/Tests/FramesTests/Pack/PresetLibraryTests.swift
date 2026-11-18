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
        sut = PresetLibrary(packs: directory.packs)
    }

    // MARK: - Test
    @Test("a pack that ships with frames names its presets <pack>/<name>, as an installed one does, and a bare name names none")
    func findsShippedPreset() throws {
        // Given
        try directory.addPack("frames", in: directory.shipped)
        try directory.write(
            #"{ "description": "a flash", "seconds": 0.4 }"#,
            to: directory.shipped.appendingPathComponent("frames/presets/transition/flash.json")
        )

        // When
        let preset = try sut.transition(PresetInstance(name: "frames/flash"))
        let bare = try sut.transition(PresetInstance(name: "flash"))

        // Then
        #expect(preset?.seconds == 0.4)
        #expect(bare == nil)
    }

    @Test("<pack>/<name> is a preset in that pack's presets, and an absolute path reads that file")
    func findsPackAndPathPresets() throws {
        // Given
        try directory.addPack("shorts")
        try directory.write(#"{ "description": "pops", "entrance": { "seconds": 0.3, "keys": [] } }"#, in: "shorts", at: "presets/animation/pop.json")
        let file = try directory.write(#"{ "description": "warm", "ops": [] }"#, in: "loose", at: "warm.json")

        // When
        let animation = try sut.animation(PresetInstance(name: "shorts/pop"))
        let filter = try sut.filter(PresetInstance(name: file.path))

        // Then
        #expect(animation?.entrance?.length == 0.3)
        #expect(filter?.description == "warm")
    }

    @Test("a preset that is not there, or in a pack that is not there, is none", arguments: ["flash", "shorts/flash", "nopack/flash", "/abs/flash.json", "a/b/c"])
    func findsNoMissingPreset(name: String) throws {
        // Given
        try directory.addPack("shorts")

        // When
        let preset = try sut.transition(PresetInstance(name: name))

        // Then
        #expect(preset == nil)
    }

    @Test("an error in a preset file names the preset as it was referred to")
    func namesPresetFile() throws {
        // Given
        try directory.addPack("shorts")
        try directory.write(#"{ "description": "x" }"#, in: "shorts", at: "presets/transition/flash.json")

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.transition(PresetInstance(name: "shorts/flash")) }
        #expect(error?.description == #"shorts/flash: top level (transition): missing key "seconds""#)
    }

    @Test("a choice's arguments fill the preset's parameters, and a parameter it leaves out takes its default")
    func readsArguments() throws {
        // Given
        try writeDip()
        let place = Place.root.appending(key: "storyline").appending(index: 1).appending(key: "transition")
        let arguments = try Fixture.object(##"{ "color": "#1B3A6B", "length": 1.2 }"##)

        // When
        let given = try #require(try sut.transition(PresetInstance(name: "studio/dip", arguments: arguments, place: place)))
        let defaults = try #require(try sut.transition(PresetInstance(name: "studio/dip")))

        // Then
        #expect(given.seconds == 1.2)
        #expect(given.cover?.source == .color("#1B3A6B"))
        #expect(given.incoming?.ease == .linear)
        #expect(defaults.seconds == 0.7)
        #expect(defaults.cover?.source == .color("#000000"))
    }

    @Test(
        "arguments a preset does not publish, of the wrong type, or that give a place a value it does not take stop, naming the choice",
        arguments: [
            (#"{ "size": 1 }"#, #"storyline[1].transition.args (preset arguments): unknown argument "size". Allowed: color, curve, length, peak"#),
            (#"{ "color": 3 }"#, "storyline[1].transition.args.color (preset arguments): expected a colour, found 3"),
            (#"{ "curve": "step" }"#, #"storyline[1].transition.args.curve (preset arguments): unknown value "step". Allowed: linear, ease-in-out"#),
            (#"{ "length": 0 }"#, #"storyline[1].transition (transition choice): its arguments give "studio/dip" a value it does not take: studio/dip: seconds (transition): a span runs for more than 0 seconds, found 0"#),
            (#"{ "peak": 1.5 }"#, #"storyline[1].transition (transition choice): its arguments give "studio/dip" a value it does not take: studio/dip: cover.keys[1].opacity (cover key): expected a number from 0 to 1, found 1.5"#)
        ]
    )
    func refusesBrokenArguments(
        arguments: String,
        message: String
    ) throws {
        // Given
        try writeDip()
        let place = Place.root.appending(key: "storyline").appending(index: 1).appending(key: "transition")
        let instance = PresetInstance(name: "studio/dip", arguments: try Fixture.object(arguments), place: place)

        // When, Then
        let error = #expect(throws: (any Error).self) { try sut.transition(instance) }
        #expect("\(error.map { "\($0)" } ?? "")" == message)
    }

    @Test("a preset that publishes no parameters takes no arguments")
    func refusesArgumentsToPlainPreset() throws {
        // Given
        try directory.addPack("shorts")
        try directory.write(#"{ "description": "pops", "entrance": { "seconds": 0.3, "keys": [] } }"#, in: "shorts", at: "presets/animation/pop.json")
        let instance = PresetInstance(name: "shorts/pop", arguments: try Fixture.object(#"{ "bounce": 0.4 }"#), place: Place.root.appending(key: "animation"))

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.animation(instance) }
        #expect(error?.description == #"animation.args (preset arguments): unknown argument "bounce". It publishes no parameters"#)
    }

    @Test("a preset file is read and checked once for the library, and each choice fills its own arguments into it")
    func readsPresetOnce() throws {
        // Given
        let file = try writeDip()
        let first = try sut.transition(PresetInstance(name: "studio/dip"))
        try directory.write(#"{ "description": "x" }"#, to: file)

        // When
        let second = try sut.transition(PresetInstance(name: "studio/dip", arguments: try Fixture.object(#"{ "length": 2 }"#)))

        // Then
        #expect(first?.seconds == 0.7)
        #expect(second?.seconds == 2)
    }

    @Test("a kind lists each pack's presets in pack name order, shipped and installed alike, with their descriptions, hidden files skipped")
    func listsPresets() throws {
        // Given
        try directory.addPack("frames", in: directory.shipped)
        try directory.write(#"{ "description": "a flash", "seconds": 0.4 }"#, to: directory.shipped.appendingPathComponent("frames/presets/transition/flash.json"))
        try directory.write("", to: directory.shipped.appendingPathComponent("frames/presets/transition/.gitkeep"))
        try directory.addPack("shorts")
        try directory.write(#"{ "description": "pushes up", "seconds": 0.3 }"#, in: "shorts", at: "presets/transition/push-up.json")
        try directory.write(#"{ "description": "pops", "entrance": { "seconds": 0.3, "keys": [] } }"#, in: "shorts", at: "presets/animation/pop.json")

        // When
        let transitions = try sut.presets(of: .transition)
        let animations = try sut.presets(of: .animation)

        // Then
        #expect(transitions == [
            PresetEntry(kind: .transition, name: "frames/flash", description: "a flash"),
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
        try directory.addPack("frames", in: directory.shipped)
        try directory.write(#"{ "description": "a flash", "seconds": 0.4 }"#, to: directory.shipped.appendingPathComponent("frames/presets/transition/flash.json"))
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
        try directory.addPack("frames", in: directory.shipped)
        try directory.write(text, to: directory.shipped.appendingPathComponent("frames/presets/transition/flash.json"))
        try directory.addPack("shorts")
        let packed = try directory.write(text, in: "shorts", at: "presets/transition/flash.json")

        // When
        let shipped = try sut.text(named: "frames/flash", kind: .transition)
        let pack = try sut.text(named: "shorts/flash", kind: .transition)
        let path = try sut.text(named: packed.path, kind: .transition)
        let missing = try sut.text(named: "frames/flash", kind: .animation)

        // Then
        #expect(shipped == text)
        #expect(pack == text)
        #expect(path == text)
        #expect(missing == nil)
    }

    // MARK: - Private
    // A dip to a colour with a parameter of each kind a transition publishes.
    @discardableResult
    private func writeDip() throws -> URL {
        try directory.addPack("studio")
        return try directory.write(
            ##"""
            { "description": "Dips to a colour, then the next clip comes up out of it.",
              "params": {
                "color":  { "type": "color", "default": "#000000", "description": "colour of the dip" },
                "curve":  { "type": "choice", "options": ["linear", "ease-in-out"], "default": "linear", "description": "pace of the fade" },
                "length": { "type": "number", "default": 0.7, "description": "seconds the dip lasts" },
                "peak":   { "type": "number", "default": 1, "description": "opacity of the colour at its fullest" } },
              "seconds": { "param": "length" }, "ease": { "param": "curve" },
              "incoming": { "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.5, "opacity": 0 }, { "t": 0.5, "opacity": 1 } ] },
              "cover": { "color": { "param": "color" },
                         "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.5, "opacity": { "param": "peak" } }, { "t": 1, "opacity": 0 } ] } }
            """##,
            in: "studio",
            at: "presets/transition/dip.json"
        )
    }
}

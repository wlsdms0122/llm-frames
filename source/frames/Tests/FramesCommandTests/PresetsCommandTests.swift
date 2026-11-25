//
//  PresetsCommandTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Testing

@testable import FramesCommand

@Suite("PresetsCommand Tests")
struct PresetsCommandTests {
    // MARK: - Property
    private let sut: TestShell
    private let flash = "{\n  \"description\": \"a white flash\",   \"seconds\": 0.4\n}\n"
    private let tick = #"{ "description": "a tick across the end", "points": [[0, 2], [0, -2], [-1, 0]], "length": 1, "inset": 0.5 }"# + "\n"

    // MARK: - Initializer
    init() throws {
        sut = try TestShell()
        try sut.write(flash, to: sut.framesPresets.appendingPathComponent("transition/flash.json"))
        try sut.write("", to: sut.framesPresets.appendingPathComponent("transition/.gitkeep"))
        try sut.addPack("shorts")
        try sut.write(
            #"{ "description": "pushes up", "seconds": 0.3 }"#,
            to: sut.installed.appendingPathComponent("shorts/presets/transition/push-up.json")
        )
        try sut.addPack("demo")
        try sut.write(
            #"{ "description": "warms the picture", "ops": [] }"#,
            to: sut.installed.appendingPathComponent("demo/presets/filter/warm.json")
        )
        try sut.write(tick, to: sut.installed.appendingPathComponent("demo/presets/head/tick.json"))
        try sut.write(
            #"{ "description": "a filled triangle", "points": [[-4, 2], [0, 0], [-4, -2]], "length": 4, "inset": 4 }"#,
            to: sut.framesPresets.appendingPathComponent("head/arrow.json")
        )
    }

    // MARK: - Test
    @Test("presets lists every kind under its name, each pack's presets in pack name order by the name a document gives them, with descriptions")
    func listsPresets() {
        // Given, When
        let code = sut.run(["presets"])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == """
            transition
              frames/flash  a white flash
              shorts/push-up  pushes up
            animation
              frames/pop  pops in
            filter
              demo/warm  warms the picture
            audio
            head
              demo/tick  a tick across the end
              frames/arrow  a filled triangle

            """)
    }

    @Test("presets <kind> lists only that kind")
    func listsKind() {
        // Given, When
        let code = sut.run(["presets", "filter"])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == "filter\n  demo/warm  warms the picture\n")
    }

    @Test("presets head lists the heads of every pack, and presets head <name> prints one as its file is written")
    func listsHeads() {
        // Given, When
        let listCode = sut.run(["presets", "head"])
        let list = sut.standardOutput
        let printCode = sut.run(["presets", "head", "demo/tick"])

        // Then
        #expect(listCode == 0)
        #expect(list == "head\n  demo/tick  a tick across the end\n  frames/arrow  a filled triangle\n")
        #expect(printCode == 0)
        #expect(sut.standardOutput == tick)
    }

    @Test("presets <kind> <name> prints the preset's JSON as its file is written, by any name a document gives it", arguments: ["frames/flash", "shorts/push-up"])
    func printsPreset(name: String) throws {
        // Given
        let expected = name == "frames/flash"
            ? flash
            : #"{ "description": "pushes up", "seconds": 0.3 }"# + "\n"

        // When
        let code = sut.run(["presets", "transition", name])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == expected)
    }

    @Test("presets <kind> <name> prints a preset that publishes parameters with its params as written")
    func printsPresetParameters() throws {
        // Given
        let text = #"""
            { "description": "dips to a colour",
              "params": { "color": { "type": "color", "default": "#000000", "description": "colour of the dip" } },
              "seconds": 0.7,
              "cover": { "kind": "solid", "color": { "param": "color" }, "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.5, "opacity": 1 }, { "t": 1, "opacity": 0 } ] } }

            """#
        try sut.write(text, to: sut.installed.appendingPathComponent("shorts/presets/transition/dip.json"))

        // When
        let code = sut.run(["presets", "transition", "shorts/dip"])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == text)
    }

    @Test(
        "an unknown kind or preset stops",
        arguments: [
            (["presets", "wipe"], #"presets: unknown kind "wipe". Known: transition, animation, filter, audio, head"#),
            (["presets", "transition", "frames/dissolve"], #"presets: unknown transition preset "frames/dissolve". The pack "frames" holds the transition presets frames/flash"#),
            (["presets", "transition", "flash"], #"presets: unknown transition preset "flash". Did you mean "frames/flash"? A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#),
            (["presets", "animation", "frames/flash"], #"presets: unknown animation preset "frames/flash". The pack "frames" holds the animation presets frames/pop"#),
            (["presets", "transition", "frames/flash", "more"], #"presets: unexpected argument "more""#)
        ]
    )
    func stopsOnUnknown(
        arguments: [String],
        message: String
    ) {
        // Given, When
        let code = sut.run(arguments)

        // Then
        #expect(code == 1)
        #expect(sut.standardError == "frames: \(message)\n")
    }

    // MARK: - Private
}

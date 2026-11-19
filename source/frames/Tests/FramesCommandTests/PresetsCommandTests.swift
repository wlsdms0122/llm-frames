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
              "cover": { "color": { "param": "color" }, "keys": [ { "t": 0, "opacity": 0 }, { "t": 0.5, "opacity": 1 }, { "t": 1, "opacity": 0 } ] } }

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
            (["presets", "wipe"], #"presets: unknown kind "wipe". Known: transition, animation, filter, audio"#),
            (["presets", "transition", "frames/dissolve"], #"presets: unknown transition preset "frames/dissolve". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#),
            (["presets", "transition", "flash"], #"presets: unknown transition preset "flash". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#),
            (["presets", "animation", "frames/flash"], #"presets: unknown animation preset "frames/flash". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#),
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

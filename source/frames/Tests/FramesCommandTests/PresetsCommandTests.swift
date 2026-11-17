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
        try sut.write(flash, to: sut.builtIn.appendingPathComponent("transition/flash.json"))
        try sut.write("", to: sut.builtIn.appendingPathComponent("transition/.gitkeep"))
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
    @Test("presets lists every kind, the built in presets first and then each pack's as <pack>/<name>, with descriptions")
    func listsPresets() {
        // Given, When
        let code = sut.run(["presets"])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == """
            transition/flash  a white flash
            transition/shorts/push-up  pushes up
            animation/pop  pops in
            filter/demo/warm  warms the picture

            """)
    }

    @Test("presets <kind> lists only that kind")
    func listsKind() {
        // Given, When
        let code = sut.run(["presets", "filter"])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == "filter/demo/warm  warms the picture\n")
    }

    @Test("presets <kind> <name> prints the preset's JSON as its file is written, by any name a document gives it", arguments: ["flash", "shorts/push-up"])
    func printsPreset(name: String) throws {
        // Given
        let expected = name == "flash"
            ? flash
            : #"{ "description": "pushes up", "seconds": 0.3 }"# + "\n"

        // When
        let code = sut.run(["presets", "transition", name])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == expected)
    }

    @Test(
        "an unknown kind or preset stops",
        arguments: [
            (["presets", "wipe"], #"presets: unknown kind "wipe". Known: transition, animation, filter"#),
            (["presets", "transition", "dissolve"], #"presets: unknown transition preset "dissolve""#),
            (["presets", "animation", "flash"], #"presets: unknown animation preset "flash""#),
            (["presets", "transition", "flash", "more"], #"presets: unexpected argument "more""#)
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

//
//  PacksCommandTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation
import Testing

@testable import FramesCommand

@Suite("PacksCommand Tests")
struct PacksCommandTests {
    // MARK: - Property
    private let sut: TestShell

    // MARK: - Initializer
    init() throws {
        sut = try TestShell()
    }

    // MARK: - Test
    @Test("packs lists the installed packs in name order, with what pack.json says and - where it says nothing")
    func listsPacks() throws {
        // Given
        try sut.addPack("shorts")
        try sut.addPack("demo", manifest: #"{ "engine": "^1" }"#)
        try sut.write("", to: sut.installed.appendingPathComponent(".DS_Store"))

        // When
        let code = sut.run(["packs"])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == """
            demo  -  -  -
            shorts  Shorts  1.2.0  Looks for shorts

            """)
    }

    @Test("packs <pack> lists what the pack holds by kind, each by the name a document gives it")
    func listsPackContents() throws {
        // Given
        let pack = try sut.addPack("shorts")
        try sut.write(#"{ "description": "pushes up", "seconds": 0.3 }"#, to: pack.appendingPathComponent("presets/transition/push-up.json"))
        try sut.write(#"{ "description": "pops", "entrance": { "seconds": 0.3, "keys": [] } }"#, to: pack.appendingPathComponent("presets/animation/pop.json"))
        try sut.write("{}", to: pack.appendingPathComponent("themes/shorts.json"))
        try sut.write(#"{ "kind": "sequence", "params": {} }"#, to: pack.appendingPathComponent("templates/intro.json"))
        try sut.write("", to: pack.appendingPathComponent("luts/warm.cube"))
        try sut.write("", to: pack.appendingPathComponent("media/leak.mov"))
        try sut.write("", to: pack.appendingPathComponent("media/.DS_Store"))
        try sut.write("", to: pack.appendingPathComponent("fonts/Pretendard-Bold.otf"))

        // When
        let code = sut.run(["packs", "shorts"])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == """
            shorts  Shorts  1.2.0  Looks for shorts
            transition  shorts/push-up  pushes up
            animation  shorts/pop  pops
            theme  shorts/shorts
            template  shorts/intro
            lut  shorts/warm
            media  shorts/leak.mov
            font  Pretendard-Bold.otf

            """)
    }

    @Test("a pack that is not there, or one without a pack.json, stops")
    func stopsOnMissingPack() throws {
        // Given
        try FileManager.default.createDirectory(at: sut.installed.appendingPathComponent("broken"), withIntermediateDirectories: true)

        // When
        let missing = sut.run(["packs", "nothing"])
        let missingError = sut.standardError
        let broken = sut.run(["packs"])

        // Then
        #expect(missing == 1)
        #expect(broken == 1)
        #expect(missingError == "frames: packs: unknown pack \"nothing\"\n")
        #expect(sut.standardError == "frames: \(sut.installed.appendingPathComponent("broken/pack.json").path): top level (manifest): a pack holds a pack.json, and this one has none\n")
    }

    // MARK: - Private
}

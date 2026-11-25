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
    @Test("packs lists the installed and shipped packs in name order, with what pack.json says and - where it says nothing")
    func listsPacks() throws {
        // Given
        try sut.addPack("shorts")
        try sut.addPack("demo", manifest: #"{ "engine": "^0.1" }"#, in: sut.shipped)
        try sut.write("", to: sut.installed.appendingPathComponent(".DS_Store"))
        try sut.write("", to: sut.shipped.appendingPathComponent(".gitkeep"))

        // When
        let code = sut.run(["packs"])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == """
            demo  -  -  -
            frames  Frames  -  -
            shorts  Shorts  1.2.0  Looks for shorts

            """)
    }

    @Test("packs <pack> lists what the pack holds by kind, each by the name a document or a command gives it, with the parameters of each preset and template under it and each tool after the files")
    func listsPackContents() throws {
        // Given
        let pack = try sut.addPack("shorts")
        try sut.write(
            #"""
            { "description": "pushes up",
              "params": { "distance": { "type": "number", "default": 1, "description": "frames it pushes" },
                          "curve": { "type": "choice", "options": ["linear", "ease-out"], "default": "ease-out", "description": "pace of the push" } },
              "seconds": 0.3,
              "incoming": { "ease": { "param": "curve" }, "keys": [ { "t": 0, "y": { "param": "distance" } }, { "t": 1, "y": 0 } ] } }
            """#,
            to: pack.appendingPathComponent("presets/transition/push-up.json")
        )
        try sut.write(#"{ "description": "pops", "entrance": { "seconds": 0.3, "keys": [] } }"#, to: pack.appendingPathComponent("presets/animation/pop.json"))
        try sut.write("{}", to: pack.appendingPathComponent("themes/shorts.json"))
        try sut.write(
            ##"""
            { "kind": "sequence",
              "params": { "length": { "type": "number", "default": 5, "description": "seconds on screen" },
                          "name": { "type": "text", "description": "the name shown" } },
              "storyline": [ { "kind": "solid", "color": "#000000", "duration": { "param": "length" } } ],
              "clips": [ { "kind": "title", "text": { "param": "name" }, "style": "title", "at": [0, 1] } ] }
            """##,
            to: pack.appendingPathComponent("templates/intro.json")
        )
        try sut.write("", to: pack.appendingPathComponent("luts/warm.cube"))
        try sut.write("", to: pack.appendingPathComponent("media/leak.mov"))
        try sut.write("", to: pack.appendingPathComponent("media/.DS_Store"))
        try sut.write("", to: pack.appendingPathComponent("fonts/Pretendard-Bold.otf"))
        try sut.addTool("captions", in: pack, script: "#!/bin/sh\n")
        try sut.addTool("autocut", in: pack, script: "#!/bin/sh\n")
        try sut.write("", to: pack.appendingPathComponent("tools/notes.txt"))

        // When
        let code = sut.run(["packs", "shorts"])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == """
            shorts  Shorts  1.2.0  Looks for shorts
            transition  shorts/push-up  pushes up
              distance  number  1  frames it pushes
              curve  choice  "ease-out"  pace of the push
            animation  shorts/pop  pops
            theme  shorts/shorts
            template  shorts/intro
              length  number  5  seconds on screen
              name  text  -  the name shown
            lut  shorts/warm
            media  shorts/leak.mov
            font  Pretendard-Bold.otf
            tool  shorts/autocut  a tool for tests
            tool  shorts/captions  a tool for tests

            """)
    }

    @Test("packs frames lists the heads the shipped pack holds after its other presets, each by the name a document gives it")
    func listsShippedHeads() throws {
        // Given
        try sut.write(
            #"{ "description": "a filled triangle", "points": [[-4, 2], [0, 0], [-4, -2]], "length": 4, "inset": 4 }"#,
            to: sut.framesPresets.appendingPathComponent("head/arrow.json")
        )
        try sut.write(
            #"{ "description": "a filled bar", "points": [[0, 2], [0, -2], [-1, -2], [-1, 2]], "length": 1, "inset": 0.5 }"#,
            to: sut.framesPresets.appendingPathComponent("head/bar.json")
        )

        // When
        let code = sut.run(["packs", "frames"])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == """
            frames  Frames  -  -
            animation  frames/pop  pops in
            head  frames/arrow  a filled triangle
            head  frames/bar  a filled bar

            """)
    }

    @Test("packs <pack> lists the parameters a template declares when the media it names is not there")
    func listsTemplateWithoutMedia() throws {
        // Given
        let pack = try sut.addPack("shorts")
        try sut.write(
            #"""
            { "kind": "sequence",
              "params": { "clip": { "type": "video", "default": "shorts/gone.mov", "description": "the clip shown" } },
              "storyline": [ { "kind": "media", "media": { "param": "clip" } }, { "kind": "media", "media": "shorts/gone.mov" } ] }
            """#,
            to: pack.appendingPathComponent("templates/promo.json")
        )

        // When
        let code = sut.run(["packs", "shorts"])

        // Then
        #expect(code == 0)
        #expect(sut.standardOutput == """
            shorts  Shorts  1.2.0  Looks for shorts
            template  shorts/promo
              clip  video  "shorts/gone.mov"  the clip shown

            """)
    }

    @Test("packs <pack> stops on a template parameter without a description, naming the template and the parameter")
    func stopsOnBrokenTemplateParameter() throws {
        // Given
        let pack = try sut.addPack("shorts")
        try sut.write(
            #"""
            { "kind": "sequence",
              "params": { "name": { "type": "text" } },
              "storyline": [ { "kind": "solid", "color": "#000000", "duration": 1 } ],
              "clips": [ { "kind": "title", "text": { "param": "name" }, "style": "title", "at": [0, 1] } ] }
            """#,
            to: pack.appendingPathComponent("templates/intro.json")
        )

        // When
        let code = sut.run(["packs", "shorts"])

        // Then
        #expect(code == 1)
        #expect(sut.standardError == "frames: shorts/intro: params.name (parameter): missing key \"description\"\n")
    }

    @Test("packs <pack> stops on a tool whose tool.json does not hold, naming its file")
    func stopsOnBrokenTool() throws {
        // Given
        let pack = try sut.addPack("shorts")
        try sut.addTool("autocut", in: pack, script: "#!/bin/sh\n")
        let manifest = try sut.write(#"{ "description": "cuts silence", "run": "missing.sh" }"#, to: pack.appendingPathComponent("tools/autocut/tool.json"))

        // When
        let code = sut.run(["packs", "shorts"])

        // Then
        #expect(code == 1)
        #expect(sut.standardError == "frames: \(manifest.path): run (tool): \"missing.sh\" is not an executable file in the tool's directory\n")
        #expect(sut.standardOutput.isEmpty)
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

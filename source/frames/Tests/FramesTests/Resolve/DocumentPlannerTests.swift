//
//  DocumentPlannerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("DocumentPlanner Tests")
struct DocumentPlannerTests {
    // MARK: - Property
    private let directory: PackDirectory
    private let sut: DocumentPlanner

    // A template of two clips, the first its argument, so a default transition would reach the second.
    private let leak = #"""
        { "kind": "sequence",
          "params": { "clip": { "type": "video" }, "intro": { "type": "sequence", "default": "shorts/intro.json" } },
          "storyline": [ { "media": { "param": "clip" }, "in": 1, "out": 3 }, { "media": { "param": "intro" } } ] }
        """#
    // A document of two solids, so the theme it starts from decides the transition between them.
    private let intro = ##"""
        { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 1 }, { "solid": "#FFFFFF", "duration": 1 } ] }
        """##

    // MARK: - Initializer
    init() throws {
        directory = try PackDirectory()
        try directory.addPack("shorts")
        try directory.write(leak, in: "shorts", at: "templates/leak.json")
        try directory.write(intro, in: "shorts", at: "media/intro.json")
        try directory.write(#"{ "defaults": { "transition": "flash" } }"#, in: "shorts", at: "themes/shorts.json")

        let media = directory.installed.appendingPathComponent("shorts/media", isDirectory: true)
        let mediaFacts = MediaFactTable(
            files: [
                media.appendingPathComponent("leak.mov").path: ProbedMedia(kind: .video, duration: 4, fps: 24),
                "/abs/run.mp4": ProbedMedia(kind: .video, duration: 30, fps: 29.97)
            ],
            imageSequences: [media.appendingPathComponent("frames").path: 12]
        )
        sut = DocumentPlanner(mediaFacts: mediaFacts, presets: Fixture.presets, library: directory.library(mediaFacts: mediaFacts))
    }

    // MARK: - Test
    @Test("a template instance plans as a nested sequence whose places continue the entry's, with media as written")
    func plansTemplateInstance() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": { "template": "shorts/leak", "args": { "clip": "shorts/leak.mov" } } } ] }
            """#)

        // When
        let plan = try sut.plan(document)

        // Then
        let nested = try #require(plan.storyline[0].source.media?.nested)
        #expect(plan.storyline[0].source.media?.reference == nil)
        #expect(plan.duration == 4)
        #expect(nested.storyline.map(\.place.description) == ["storyline[0].media.storyline[0]", "storyline[0].media.storyline[1]"])
        #expect(nested.storyline[0].source.media?.reference == "shorts/leak.mov")
        #expect(nested.storyline[0].source.media?.file == directory.installed.appendingPathComponent("shorts/media/leak.mov").path)
        #expect(nested.storyline[1].source.media?.reference == "shorts/intro.json")
        #expect(nested.storyline[1].source.media?.nested?.storyline[1].place.description == "storyline[0].media.storyline[1].media.storyline[1]")
    }

    @Test("a template resolves on the base theme, and a document given to it as an argument starts from the caller's theme")
    func plansThemes() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "theme": { "defaults": { "transition": "flash" } },
              "storyline": [ { "media": { "template": "shorts/leak", "args": { "clip": "shorts/leak.mov", "intro": \#(intro) } } } ] }
            """#)

        // When
        let plan = try sut.plan(document)

        // Then
        let template = try #require(plan.storyline[0].source.media?.nested)
        let argument = try #require(template.storyline[1].source.media?.nested)
        #expect(template.storyline[1].transition == nil)
        #expect(argument.storyline[1].transition?.preset == "flash")
    }

    @Test("a template's default document is written in the template, so it keeps the template's theme")
    func plansDefaultInTemplateTheme() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "theme": { "defaults": { "transition": "flash" } },
              "storyline": [ { "media": { "template": "shorts/leak", "args": { "clip": "shorts/leak.mov" } } } ] }
            """#)

        // When
        let plan = try sut.plan(document)

        // Then
        let intro = try #require(plan.storyline[0].source.media?.nested?.storyline[1].source.media?.nested)
        #expect(intro.storyline[1].transition == nil)
    }

    @Test("a document named by its file starts from the theme where it is written, with places continued from the entry")
    func plansDocumentFile() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "theme": "shorts/shorts", "storyline": [ { "media": "shorts/intro.json" } ] }
            """#)

        // When
        let plan = try sut.plan(document)

        // Then
        let nested = try #require(plan.storyline[0].source.media?.nested)
        #expect(plan.storyline[0].source.media?.reference == "shorts/intro.json")
        #expect(nested.storyline[1].place.description == "storyline[0].media.storyline[1]")
        #expect(nested.storyline[1].transition?.preset == "flash")
    }

    @Test("pack media and image sequence directories are found in the pack before they are probed")
    func probesPackMedia() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "shorts/leak.mov" }, { "media": { "imageSequence": "shorts/frames", "fps": 12 } } ] }
            """#)

        // When
        let plan = try sut.plan(document)

        // Then
        #expect(plan.storyline.map(\.edit) == [TimeRange(start: 0, end: 4), TimeRange(start: 4, end: 5)])
        #expect(plan.storyline[1].source.media?.reference == "shorts/frames")
    }

    @Test("--theme merges over the base theme, under the document's own theme")
    func mergesThemeOption() throws {
        // Given
        let document = try Fixture.json(intro)

        // When
        let plan = try sut.plan(document, theme: "shorts/shorts")

        // Then
        #expect(plan.storyline[1].transition?.preset == "flash")
    }

    @Test(
        "a theme that names nothing stops",
        arguments: [
            (nil, ##"{ "kind": "sequence", "theme": "shorts/none", "storyline": [ { "solid": "#000000", "duration": 1 } ] }"##,
             #"theme (sequence): unknown theme "shorts/none". A theme is named <pack>/<name> or by an absolute path"#),
            ("nopack/shorts", ##"{ "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 1 } ] }"##,
             #"--theme: unknown theme "nopack/shorts". A theme is named <pack>/<name> or by an absolute path"#)
        ] as [(String?, String, String)]
    )
    func refusesUnknownTheme(theme: String?, text: String, message: String) throws {
        // Given
        let document = try Fixture.json(text)

        // When, Then
        let error = #expect(throws: (any Error).self) { try sut.plan(document, theme: theme) }
        #expect(error.map { "\($0)" } == message)
    }

    @Test("an error in a theme file is reported in that file, named as it was referred to")
    func namesThemeFile() throws {
        // Given
        try directory.write(#"{ "defaults": { "transition": "dissolve" } }"#, in: "shorts", at: "themes/broken.json")
        let document = try Fixture.json(##"{ "kind": "sequence", "theme": "shorts/broken", "storyline": [ { "solid": "#000000", "duration": 1 } ] }"##)

        // When, Then
        let error = #expect(throws: ThemeError.self) { try sut.plan(document) }
        #expect(error?.description == #"shorts/broken: defaults.transition (defaults): unknown transition preset "dissolve""#)
    }

    @Test("a resolve error inside a template instance continues the entry's place")
    func continuesPlaceInInstance() throws {
        // Given
        try directory.write(
            #"{ "kind": "sequence", "params": { "clip": { "type": "video" } }, "storyline": [ { "media": { "param": "clip" }, "in": 5 } ] }"#,
            in: "shorts",
            at: "templates/late.json"
        )
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": { "template": "shorts/late", "args": { "clip": "shorts/leak.mov" } } } ] }
            """#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document) }
        #expect(error?.description == "storyline[0].media.storyline[0] (video): in 5 is at or after the end of the media at 4")
    }

    @Test("a template given as the document takes its arguments from --args, checked in that file")
    func plansTemplateWithArguments() throws {
        // Given
        let document = try Fixture.json(leak)
        let arguments = ArgumentFile(name: "/abs/args.json", value: try Fixture.json(#"{ "clip": "shorts/leak.mov" }"#))
        let wrong = ArgumentFile(name: "/abs/args.json", value: try Fixture.json(#"{ "clip": 3 }"#))
        let list = ArgumentFile(name: "/abs/args.json", value: try Fixture.json("[1]"))

        // When
        let plan = try sut.plan(document, arguments: arguments)

        // Then
        #expect(plan.storyline[0].source.media?.reference == "shorts/leak.mov")
        #expect(plan.storyline[0].place.description == "storyline[0]")
        let wrongError = #expect(throws: (any Error).self) { try sut.plan(document, arguments: wrong) }
        #expect(wrongError.map { "\($0)" } == "/abs/args.json: clip (template arguments): expected a media reference, found 3")
        let listError = #expect(throws: ModelError.self) { try sut.plan(document, arguments: list) }
        #expect(listError?.description == "/abs/args.json: top level (template arguments): expected an object, found a list of 1")
    }

    @Test("a template given as the document without --args needs a default for every parameter")
    func refusesTemplateWithoutArguments() throws {
        // Given
        let document = try Fixture.json(leak)

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.plan(document) }
        #expect(error?.description == #"top level (template arguments): missing argument "clip", which has no default"#)
    }

    @Test("a template takes no --theme, and a document that is not a template takes no --args")
    func refusesThemeOnTemplateAndArgumentsWithoutTemplate() throws {
        // Given
        let template = try Fixture.json(leak)
        let document = try Fixture.json(intro)
        let arguments = ArgumentFile(name: "/abs/args.json", value: try Fixture.json("{}"))

        // When, Then
        let themeError = #expect(throws: PackError.self) { try sut.plan(template, theme: "shorts/shorts", arguments: arguments) }
        #expect(themeError?.description == "top level (sequence): a template resolves on the base theme and its own theme, so it takes no --theme")
        let argumentsError = #expect(throws: PackError.self) { try sut.plan(document, arguments: arguments) }
        #expect(argumentsError?.description == "top level (sequence): the document declares no params, so it takes no arguments")
    }

    @Test("an unknown template stops where it is named")
    func refusesUnknownTemplate() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": { "template": "shorts/none" } } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.plan(document) }
        #expect(error?.description == #"storyline[0].media.template (storyline clip): unknown template "shorts/none""#)
    }
}

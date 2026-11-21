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
          "params": { "clip": { "type": "video", "description": "the clip" }, "intro": { "type": "sequence", "default": "shorts/intro.json", "description": "the intro" } },
          "storyline": [ { "media": { "param": "clip" }, "in": 1, "out": 3 }, { "media": { "param": "intro" } } ] }
        """#
    // A document of two solids, so the theme it starts from decides the transition between them. Solids have no size,
    // so it gives its own.
    private let intro = ##"""
        { "kind": "sequence", "format": { "size": [1080, 1920] },
          "storyline": [ { "solid": "#000000", "duration": 1 }, { "solid": "#FFFFFF", "duration": 1 } ] }
        """##

    // MARK: - Initializer
    init() throws {
        directory = try PackDirectory()
        try directory.addPack("shorts")
        try directory.write(leak, in: "shorts", at: "templates/leak.json")
        try directory.write(intro, in: "shorts", at: "media/intro.json")
        try directory.write(#"{ "defaults": { "transition": "frames/flash" } }"#, in: "shorts", at: "themes/shorts.json")

        let media = directory.installed.appendingPathComponent("shorts/media", isDirectory: true)
        let mediaFacts = MediaFactTable(
            files: [
                media.appendingPathComponent("leak.mov").path: ProbedMedia(kind: .video, duration: 4, fps: 24, size: Size(width: 1080, height: 1920)),
                "/abs/run.mp4": ProbedMedia(kind: .video, duration: 30, fps: 29.97, size: Size(width: 1080, height: 1920)),
                "/abs/page.png": ProbedMedia(kind: .image, size: Size(width: 1000, height: 800))
            ],
            imageSequences: [
                media.appendingPathComponent("frames").path: (1...12).map { media.appendingPathComponent("frames/\($0).png").path }
            ],
            pages: ["/abs/deck.pdf": [Size(width: 200, height: 100), Size(width: 200, height: 100)]]
        )
        sut = DocumentPlanner(
            mediaFacts: mediaFacts,
            presets: Fixture.presets,
            ocr: Fixture.ocr,
            languages: nil,
            tracker: Fixture.tracker,
            shaper: Fixture.shaper,
            library: directory.library(mediaFacts: mediaFacts)
        )
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
        let nested = try #require(plan.time.storyline[0].source.media?.sequence)
        #expect(plan.time.storyline[0].source.media?.reference == nil)
        #expect(plan.time.duration == 4)
        #expect(nested.storyline.map(\.place.description) == ["storyline[0].media.storyline[0]", "storyline[0].media.storyline[1]"])
        #expect(nested.storyline[0].source.media?.reference == "shorts/leak.mov")
        #expect(nested.storyline[0].source.media?.file?.path == directory.installed.appendingPathComponent("shorts/media/leak.mov").path)
        #expect(nested.storyline[1].source.media?.reference == "shorts/intro.json")
        #expect(nested.storyline[1].source.media?.sequence?.storyline[1].place.description == "storyline[0].media.storyline[1].media.storyline[1]")
    }

    @Test("a template resolves on the base theme, and a document given to it as an argument starts from the caller's theme")
    func plansThemes() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "theme": { "defaults": { "transition": "frames/flash" } },
              "storyline": [ { "media": { "template": "shorts/leak", "args": { "clip": "shorts/leak.mov", "intro": \#(intro) } } } ] }
            """#)

        // When
        let plan = try sut.plan(document)

        // Then
        let template = try #require(plan.time.storyline[0].source.media?.sequence)
        let argument = try #require(template.storyline[1].source.media?.sequence)
        #expect(template.storyline[1].transition == nil)
        #expect(argument.storyline[1].transition?.preset == "frames/flash")
    }

    @Test("a template's default document is written in the template, so it keeps the template's theme")
    func plansDefaultInTemplateTheme() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "theme": { "defaults": { "transition": "frames/flash" } },
              "storyline": [ { "media": { "template": "shorts/leak", "args": { "clip": "shorts/leak.mov" } } } ] }
            """#)

        // When
        let plan = try sut.plan(document)

        // Then
        let intro = try #require(plan.time.storyline[0].source.media?.sequence?.storyline[1].source.media?.sequence)
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
        let nested = try #require(plan.time.storyline[0].source.media?.sequence)
        #expect(plan.time.storyline[0].source.media?.reference == "shorts/intro.json")
        #expect(nested.storyline[1].place.description == "storyline[0].media.storyline[1]")
        #expect(nested.storyline[1].transition?.preset == "frames/flash")
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
        #expect(plan.time.storyline.map(\.edit) == [TimeRange(start: 0, end: 4), TimeRange(start: 4, end: 5)])
        #expect(plan.time.storyline[1].source.media?.reference == "shorts/frames")
    }

    @Test("--theme merges over the base theme, under the document's own theme")
    func mergesThemeOption() throws {
        // Given
        let document = try Fixture.json(intro)

        // When
        let plan = try sut.plan(document, theme: "shorts/shorts")

        // Then
        #expect(plan.time.storyline[1].transition?.preset == "frames/flash")
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
        #expect(error?.description == #"shorts/broken: defaults.transition (defaults): unknown transition preset "dissolve". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#)
    }

    @Test("a resolve error inside a template instance continues the entry's place")
    func continuesPlaceInInstance() throws {
        // Given
        try directory.write(
            #"{ "kind": "sequence", "params": { "clip": { "type": "video", "description": "the clip" } }, "storyline": [ { "media": { "param": "clip" }, "in": 5 } ] }"#,
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

    @Test("toneMap on a clip of a page an instance is given stops where resolve reads it, continuing the entry's place")
    func continuesPlaceOfPageArgumentStop() throws {
        // Given
        try directory.write(
            #"{ "kind": "sequence", "params": { "still": { "type": "image", "description": "the still" } }, "storyline": [ { "media": { "param": "still" }, "duration": 2, "toneMap": false } ] }"#,
            in: "shorts",
            at: "templates/still.json"
        )
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": { "template": "shorts/still", "args": { "still": { "file": "/abs/deck.pdf", "page": 2 } } } } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.plan(document) }
        #expect(error?.description.hasPrefix(#"storyline[0].media.storyline[0] (page): unknown key "toneMap". Allowed: "#) == true)
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
        #expect(plan.time.storyline[0].source.media?.reference == "shorts/leak.mov")
        #expect(plan.time.storyline[0].place.description == "storyline[0]")
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
        let error = #expect(throws: ParameterError.self) { try sut.plan(document) }
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

    @Test("a document given to a template as an argument that holds that document stops instead of never ending")
    func refusesSelfReferenceThroughArgument() throws {
        // Given
        try directory.write(
            #"{ "kind": "sequence", "params": { "clip": { "type": "sequence", "description": "the clip" } }, "storyline": [ { "media": { "param": "clip" } } ] }"#,
            in: "shorts",
            at: "templates/wrap.json"
        )
        try directory.write(
            #"{ "kind": "sequence", "storyline": [ { "media": { "template": "shorts/wrap", "args": { "clip": "shorts/loop.json" } } } ] }"#,
            in: "shorts",
            at: "media/loop.json"
        )
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": "shorts/loop.json" } ] }"#)
        let loop = directory.installed.appendingPathComponent("shorts/media/loop.json").path

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.plan(document) }
        #expect(error == .circularReference(place: Place(file: "shorts/loop.json", components: []), files: [loop, loop]))
    }

    @Test("a template may be given a document that holds another instance of it, since that instance ends")
    func plansInstanceInsideArgument() throws {
        // Given
        try directory.write(
            #"{ "kind": "sequence", "params": { "clip": { "type": "sequence", "description": "the clip" } }, "storyline": [ { "media": { "param": "clip" } } ] }"#,
            in: "shorts",
            at: "templates/wrap.json"
        )
        try directory.write(
            #"{ "kind": "sequence", "storyline": [ { "media": { "template": "shorts/wrap", "args": { "clip": "shorts/intro.json" } } } ] }"#,
            in: "shorts",
            at: "media/outro.json"
        )
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": { "template": "shorts/wrap", "args": { "clip": "shorts/outro.json" } } } ] }
            """#)

        // When
        let plan = try sut.plan(document)

        // Then
        #expect(plan.time.duration == 2)
    }

    @Test("a template's default document that holds an instance of that template stops instead of never ending")
    func refusesSelfReferenceThroughDefault() throws {
        // Given
        try directory.write(
            #"""
            { "kind": "sequence", "params": { "clip": { "type": "sequence", "default": "shorts/loop.json", "description": "the clip" } },
              "storyline": [ { "media": { "param": "clip" } } ] }
            """#,
            in: "shorts",
            at: "templates/wrap.json"
        )
        try directory.write(
            #"{ "kind": "sequence", "storyline": [ { "media": { "template": "shorts/wrap" } } ] }"#,
            in: "shorts",
            at: "media/loop.json"
        )
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": "shorts/loop.json" } ] }"#)
        let loop = directory.installed.appendingPathComponent("shorts/media/loop.json").path

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.plan(document) }
        #expect(error == .circularReference(place: Place(file: "shorts/loop.json", components: []), files: [loop, loop]))
    }

    @Test("a template whose default is an instance of itself stops instead of never ending")
    func refusesSelfInstanceThroughDefault() throws {
        // Given
        try directory.write(
            #"""
            { "kind": "sequence", "params": { "m": { "type": "sequence", "default": { "template": "shorts/self" }, "description": "the m" } },
              "storyline": [ { "media": { "param": "m" } } ] }
            """#,
            in: "shorts",
            at: "templates/self.json"
        )
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": { "template": "shorts/self" } } ] }"#)

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.plan(document) }
        #expect(error == .circularReference(place: Place(file: "shorts/self", components: []), files: ["shorts/self", "shorts/self"]))
    }

    @Test("a template that passes its own argument on to an instance of itself stops instead of never ending")
    func refusesSelfInstancePassingArgument() throws {
        // Given
        try directory.write(
            #"""
            { "kind": "sequence", "params": { "m": { "type": "sequence", "default": "shorts/intro.json", "description": "the m" } },
              "storyline": [ { "media": { "template": "shorts/self", "args": { "m": { "param": "m" } } } } ] }
            """#,
            in: "shorts",
            at: "templates/self.json"
        )
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": { "template": "shorts/self" } } ] }"#)
        let file = directory.installed.appendingPathComponent("shorts/templates/self.json").path

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.plan(document) }
        #expect(error == .circularReference(place: Place(file: "shorts/self", components: []), files: [file, file]))
    }

    @Test("an unknown template stops where it is named")
    func refusesUnknownTemplate() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": { "template": "shorts/none" } } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.plan(document) }
        #expect(error?.description == #"storyline[0].media.template (storyline clip): unknown template "shorts/none""#)
    }

    @Test("a title's `character.font` inside a pack's template looks in that pack's fonts before the machine's")
    func findsCharacterFontInTemplatePack() throws {
        // Given
        let font = try directory.write("", in: "shorts", at: "fonts/Inter-Regular.otf").path
        try directory.write(
            #"""
            { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [ { "solid": "#000000", "duration": 1 } ],
              "clips": [ { "title": "Hi", "style": "title", "character": { "font": ["Inter"] }, "position": [400, 225], "at": [0, 1] } ] }
            """#,
            in: "shorts",
            at: "templates/card.json"
        )
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": { "template": "shorts/card" } } ] }"#)

        // When
        let plan = try sut.plan(document)

        // Then
        let title = try #require(plan.storyline[0].nested?.clips[0].title?.layout)
        #expect(title.runs.map(\.face.file) == [font])
    }

    @Test("a title's `character.font` in a document looks at the machine's fonts only, and its stop names it")
    func refusesCharacterFontOutsidePack() throws {
        // Given
        let font = try directory.write("", in: "shorts", at: "fonts/Inter-Regular.otf").path
        try directory.write(#"{ "font": ["Inter"] }"#, in: "shorts", at: "themes/inter.json")
        let styled = try Fixture.json(#"""
            { "kind": "sequence", "theme": "shorts/inter", "storyline": [ { "media": "/abs/run.mp4" } ],
              "clips": [ { "title": "Hi", "style": "title", "position": [400, 225], "at": [0, 1] } ] }
            """#)
        let document = try Fixture.json(#"""
            { "kind": "sequence", "theme": "shorts/inter", "storyline": [ { "media": "/abs/run.mp4" } ],
              "clips": [ { "title": "Hi", "style": "title", "character": { "font": ["Inter"] }, "position": [400, 225], "at": [0, 1] } ] }
            """#)

        // When
        let plan = try sut.plan(styled)

        // Then
        #expect(plan.clips[0].title?.layout.runs.map(\.face.file) == [font])
        let error = #expect(throws: TextError.self) { try sut.plan(document) }
        #expect(error?.description == #"""
            clips[0].character.font (title): no family of "Inter" is in its pack or on the machine
            """#)
    }
}

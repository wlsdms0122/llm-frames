//
//  ReferenceLibraryTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("ReferenceLibrary Tests")
struct ReferenceLibraryTests {
    // MARK: - Property
    private let directory: PackDirectory
    private let sut: ReferenceLibrary

    // MARK: - Initializer
    init() throws {
        directory = try PackDirectory()
        try directory.addPack("shorts")
        let leak = directory.installed.appendingPathComponent("shorts/media/leak.mov").path
        sut = directory.library(mediaFacts: MediaFactTable(files: [leak: ProbedMedia(kind: .video, duration: 4)]))
    }

    // MARK: - Test
    @Test("a theme is <pack>/<name> in the pack's themes or an absolute path, and its place names it as written")
    func findsTheme() throws {
        // Given
        try directory.write(#"{ "defaults": { "transition": "frames/flash" } }"#, in: "shorts", at: "themes/shorts.json")
        let file = try directory.write(#"{ "baseWidth": 1080 }"#, in: "loose", at: "wide.json")

        // When
        let packTheme = try sut.theme(named: "shorts/shorts")
        let pathTheme = try sut.theme(named: file.path)
        let bareTheme = try sut.theme(named: "shorts")

        // Then
        #expect(packTheme == ThemeLayer(value: try Fixture.json(#"{ "defaults": { "transition": "frames/flash" } }"#), place: Place(file: "shorts/shorts", components: []), pack: "shorts"))
        #expect(pathTheme?.place.description == "\(file.path): top level")
        #expect(bareTheme == nil)
    }

    @Test("a template is read from the pack's templates and checked")
    func findsTemplate() throws {
        // Given
        try directory.write(
            #"""
            { "kind": "sequence", "params": { "clip": { "type": "video", "description": "the clip" }, "title": { "type": "text", "default": "New", "description": "the title" } },
              "storyline": [ { "media": { "param": "clip" }, "connected": [ { "title": { "param": "title" }, "style": "title" } ] } ] }
            """#,
            in: "shorts",
            at: "templates/leak.json"
        )

        // When
        let template = try #require(try sut.template(named: "shorts/leak"))

        // Then
        #expect(template.place.description == "shorts/leak: top level")
        #expect(template.parameters == [
            Parameter(name: "clip", type: .video, description: "the clip"),
            Parameter(name: "title", type: .text, defaultValue: .string("New"), description: "the title")
        ])
        #expect(template.references.map(\.place.description) == [
            "shorts/leak: storyline[0].media",
            "shorts/leak: storyline[0].connected[0].title"
        ])
        #expect(try sut.hasTemplate(named: "shorts/leak"))
    }

    @Test("a template's declared parameters are read from its params alone, so media it names that is not there does not stop them")
    func readsTemplateParameters() throws {
        // Given
        try directory.write(
            #"""
            { "kind": "sequence", "params": { "clip": { "type": "video", "default": "shorts/gone.mov", "description": "the clip" } },
              "storyline": [ { "media": { "param": "clip" } }, { "media": "shorts/gone.mov" } ] }
            """#,
            in: "shorts",
            at: "templates/promo.json"
        )

        // When
        let parameters = try sut.templateParameters(named: "shorts/promo")
        let missing = try sut.templateParameters(named: "shorts/nothing")

        // Then
        #expect(parameters == [Parameter(name: "clip", type: .video, defaultValue: .string("shorts/gone.mov"), description: "the clip")])
        #expect(missing == nil)
        #expect(throws: ModelError.missingMedia(place: Place(file: "shorts/promo", components: [.key("storyline"), .index(1, id: nil), .key("media")]), kind: "storyline clip", reference: "shorts/gone.mov")) {
            try sut.template(named: "shorts/promo")
        }
    }

    @Test("a template's declared parameter without a description stops where it is declared")
    func stopsOnUndescribedParameter() throws {
        // Given
        try directory.write(
            #"""
            { "kind": "sequence", "params": { "clip": { "type": "video" } }, "storyline": [ { "media": { "param": "clip" } } ] }
            """#,
            in: "shorts",
            at: "templates/promo.json"
        )

        // When
        let error = #expect(throws: ModelError.self) {
            try sut.templateParameters(named: "shorts/promo")
        }

        // Then
        #expect(error?.description == "shorts/promo: params.clip (parameter): missing key \"description\"")
    }

    @Test("an error in a template file names the template as it was referred to, with the place in that file")
    func namesTemplateFile() throws {
        // Given
        try directory.write(
            #"{ "kind": "sequence", "params": {}, "storyline": [ { "media": "shorts/leak.mov", "spead": 2 } ] }"#,
            in: "shorts",
            at: "templates/leak.json"
        )

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.template(named: "shorts/leak") }
        #expect(error?.description == #"shorts/leak: storyline[0] (video): unknown key "spead". Allowed: id, metadata, media, in, out, speed, crop, filter, transition, anchor, position, scale, rotation, opacity, blend, mask, trackMatte, track, radius, border, shadow, volume, pan, fadeIn, fadeOut, audioFilter, split, keyframes, connected"#)
    }

    @Test("media the probe cannot read throws the probe's failure without a place, for the place that names it to stop at")
    func givesProbeFailure() throws {
        // Given
        let leak = directory.installed.appendingPathComponent("shorts/media/leak.mov").path
        let sut = directory.library(
            mediaFacts: MediaFactTable(files: [:], failures: [leak: ProbeFailure("media \(leak) cannot be read")])
        )

        // When
        let error = #expect(throws: UnreadableMediaError.self) { try sut.mediaKind(of: "shorts/leak.mov") }

        // Then
        #expect((error?.reason as? ProbeFailure)?.description == "media \(leak) cannot be read")
    }

    @Test("a document naming media the probe cannot read stops once, at the place it names it, with the probe's reason")
    func refusesUnreadableMedia() throws {
        // Given
        let leak = directory.installed.appendingPathComponent("shorts/media/leak.mov").path
        let sut = directory.library(
            mediaFacts: MediaFactTable(files: [:], failures: [leak: ProbeFailure("media \(leak) cannot be read")])
        )
        try directory.write(#"{ "kind": "sequence", "storyline": [ { "media": "shorts/leak.mov" } ] }"#, in: "shorts", at: "media/intro.json")

        // When
        let error = #expect(throws: ModelError.self) { try sut.mediaKind(of: "shorts/intro.json") }

        // Then
        #expect(error?.description == #"shorts/intro.json: storyline[0].media (storyline clip): media "shorts/leak.mov" cannot be probed: media \#(leak) cannot be read"#)
    }

    @Test("media named <pack>/<file> is the file in the pack's media, and its kind is the one its probe finds")
    func findsPackMedia() throws {
        // Given
        let leak = directory.installed.appendingPathComponent("shorts/media/leak.mov").path

        // When
        let file = try sut.mediaFile(named: "shorts/leak.mov")
        let kind = try sut.mediaKind(of: "shorts/leak.mov")

        // Then
        #expect(file == leak)
        #expect(kind == .video)
        #expect(try sut.mediaFile(named: "leak.mov") == nil)
        #expect(try sut.mediaFile(named: "nopack/leak.mov") == nil)
    }

    @Test("a .json document used as media is read from the pack's media, checked, and has the kind of document it is")
    func findsDocument() throws {
        // Given
        try directory.write(#"{ "kind": "sequence", "storyline": [ { "media": "shorts/leak.mov" } ] }"#, in: "shorts", at: "media/intro.json")

        // When
        let kind = try sut.mediaKind(of: "shorts/intro.json")

        // Then
        #expect(kind == .sequence)
    }

    @Test("a document used by file may not be a template, and its errors name it")
    func refusesTemplateByFile() throws {
        // Given
        try directory.write(
            #"{ "kind": "sequence", "params": { "c": { "type": "video", "description": "the c" } }, "storyline": [ { "media": { "param": "c" } } ] }"#,
            in: "shorts",
            at: "media/intro.json"
        )

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.mediaKind(of: "shorts/intro.json") }
        #expect(error?.description == "shorts/intro.json: top level (sequence): a document with params is a template and is used only as a template instance")
    }

    @Test("a document that holds itself, directly or through another, stops instead of never ending")
    func refusesSelfReference() throws {
        // Given
        let a = directory.installed.appendingPathComponent("shorts/media/a.json").path
        let b = directory.installed.appendingPathComponent("shorts/media/b.json").path
        try directory.write(#"{ "kind": "sequence", "storyline": [ { "media": "shorts/b.json" } ] }"#, in: "shorts", at: "media/a.json")
        try directory.write(#"{ "kind": "sequence", "storyline": [ { "media": "shorts/a.json" } ] }"#, in: "shorts", at: "media/b.json")

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.mediaKind(of: "shorts/a.json") }
        #expect(error == .circularReference(place: Place(file: "shorts/a.json", components: []), files: [a, b, a]))
        #expect(error?.description == #"shorts/a.json: top level (document): it holds itself through "\#(a)", "\#(b)", "\#(a)", so it never ends"#)
    }

    @Test("a template that holds an instance of itself stops")
    func refusesSelfInstance() throws {
        // Given
        try directory.write(
            #"{ "kind": "sequence", "params": {}, "storyline": [ { "media": { "template": "shorts/loop" } } ] }"#,
            in: "shorts",
            at: "templates/loop.json"
        )

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.template(named: "shorts/loop") }
        let file = directory.installed.appendingPathComponent("shorts/templates/loop.json").path
        #expect(error == .circularReference(place: Place(file: "shorts/loop", components: []), files: [file, file]))
    }

    @Test("a syntax error in a file names it as it was referred to")
    func namesSyntaxError() throws {
        // Given
        try directory.write(#"{ "defaults": }"#, in: "shorts", at: "themes/broken.json")

        // When, Then
        let error = #expect(throws: JSONError.self) { try sut.theme(named: "shorts/broken") }
        #expect(error?.description == "shorts/broken: line 1, column 15: unexpected character")
    }
}

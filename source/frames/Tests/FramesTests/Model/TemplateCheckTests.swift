//
//  TemplateCheckTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("Template Check Tests")
struct TemplateCheckTests {
    // MARK: - Property
    private let sut = KeyChecker(mediaKinds: Fixture.mediaKinds)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a template's parameters stand for values of their type")
    func acceptsParameters() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence",
              "params": {
                "clip":  { "type": "video", "description": "the recording" },
                "name":  { "type": "text", "default": "Ada" },
                "tint":  { "type": "color", "default": "#FF0000" },
                "size":  { "type": "number", "default": 2 },
                "tone":  { "type": "choice", "options": ["frames/warm", "frames/cool"], "default": "frames/warm", "description": "colour of the whole clip" }
              },
              "storyline": [ { "media": { "param": "clip" }, "in": 1, "filter": { "param": "tone" },
                               "connected": [ { "shape": "box", "area": { "param": "name" }, "color": { "param": "tint" }, "opacity": { "param": "size" } } ] } ]
            }
            """##)

        // When, Then
        try sut.check(document: document)
    }

    @Test("a media parameter's type picks the media row")
    func picksRowByParameterType() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "params": { "card": { "type": "image" } },
              "storyline": [ { "media": { "param": "card" }, "in": 1 } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[0] (image): unknown key "in". Allowed: id, metadata, media, duration, crop, filter, transition, keyframes, connected"#)
    }

    @Test(
        "a parameter that cannot stand where it is written stops",
        arguments: [
            (#"{ "name": { "type": "text" } }"#, #"{ "title": "x", "style": { "param": "name" } }"#,
             #"clips[0].style (title): parameter "name" of type text cannot stand where a string is expected"#),
            (#"{ "size": { "type": "number" } }"#, #"{ "title": { "param": "size" }, "style": "s" }"#,
             #"clips[0].title (title): parameter "size" of type number cannot stand where a string is expected"#),
            (#"{ "name": { "type": "text" } }"#, #"{ "media": { "param": "name" } }"#,
             #"clips[0].media (clip): parameter "name" of type text cannot stand where a media reference is expected"#),
            (#"{ "where": { "type": "choice", "options": ["top", "middle"] } }"#, #"{ "title": "x", "style": "s", "placement": { "param": "where" } }"#,
             #"clips[0].placement (title): unknown value "middle". Allowed: top-left, top, top-right, left, center, right, bottom-left, bottom, bottom-right"#),
            (#"{ "name": { "type": "text" } }"#, #"{ "title": { "param": "nam" }, "style": "s" }"#,
             #"clips[0].title (title): parameter "nam" is not declared in params"#)
        ]
    )
    func refusesMisplacedParameter(
        parameters: String,
        clip: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "params": \#(parameters), "clips": [ \#(clip) ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("a declared parameter that nothing refers to stops")
    func refusesUnusedParameter() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "params": { "name": { "type": "text" } }, "clips": [] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"params.name (parameter): "name" is declared but nothing in the template refers to it"#)
    }

    @Test(
        "a parameter takes only its own keys, and options only as a choice",
        arguments: [
            (#"{ "type": "text", "options": ["a"] }"#, #"params.p (parameter): unknown key "options". Allowed: type, default, description"#),
            (#"{ "type": "choice" }"#, #"params.p (parameter): missing key "options""#),
            (#"{ "type": "choice", "options": [] }"#, #"params.p.options (parameter): a choice offers at least one option"#),
            (#"{ "type": "font" }"#, #"params.p.type (parameter): unknown value "font". Allowed: video, sequence, image, audio, text, color, number, choice"#),
            (#"{ "type": "number", "default": "2" }"#, #"params.p.default (parameter): expected a number, found "2""#),
            (#"{ "type": "choice", "options": ["a", "b"], "default": "c" }"#, #"params.p.default (parameter): unknown value "c". Allowed: a, b"#),
            (#"{ "default": 1 }"#, #"params.p (parameter): missing key "type""#),
            (#"{ "type": "text", "label": "x" }"#, #"params.p (parameter): unknown key "label". Allowed: type, default, description, options"#)
        ]
    )
    func checksParameterKeys(
        parameter: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "params": { "p": \#(parameter) }, "clips": [ { "title": { "param": "p" }, "style": "s" } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("a template instance takes template and args")
    func checksTemplateInstance() throws {
        // Given
        let compound = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": { "template": "pack/intro", "args": { "name": "Ada" } }, "in": 0, "out": 3 } ] }"#)
        let unknownKey = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": { "template": "pack/intro", "arguments": {} } } ] }"#)

        // When, Then
        try sut.check(document: compound)
        let error = #expect(throws: ModelError.self) { try sut.check(document: unknownKey) }
        #expect(error?.description == #"storyline[0].media (template instance): unknown key "arguments". Allowed: template, args"#)
    }

    @Test("a document with params used anywhere but as a template instance stops")
    func refusesNestedTemplate() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": { "kind": "sequence", "params": {}, "storyline": [] }, "in": 0, "out": 1 } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == "storyline[0].media (sequence): a document with params is a template and is used only as a template instance")
    }

    @Test("a document given as an argument is checked like any document")
    func checksDocumentArgument() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": { "template": "pack/intro", "args": { "shot": { "kind": "sequence", "storyline": [], "opz": [] } } } } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[0].media.args.shot (sequence): unknown key "opz". Allowed: kind, format, theme, params, storyline, clips"#)
    }

    @Test("a template named by a choice parameter takes the probed kind its options share")
    func readsTemplateNamedByChoice() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "params": { "t": { "type": "choice", "options": ["pack/intro", "pack/outro"] } },
              "storyline": [ { "media": { "template": { "param": "t" }, "args": {} }, "in": 0, "out": 2 } ] }
            """#)
        let checker = KeyChecker(mediaKinds: MediaKindTable(templates: ["pack/intro", "pack/outro"]))

        // When, Then
        try checker.check(document: document)
    }

    @Test("a parameter used only inside a template instance given as an argument counts as used")
    func recordsParameterInsideArgumentInstance() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "params": { "p": { "type": "text" } },
              "storyline": [ { "media": { "template": "pack/intro", "args": { "x": { "template": "pack/card", "args": { "y": { "param": "p" } } } } } } ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test("a media object given as an argument is checked like any media")
    func checksMediaArgument() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": { "template": "pack/intro", "args": { "frames": { "imageSequence": "/abs/frames" } } } } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[0].media.args.frames (image sequence): missing key "fps""#)
    }

    @Test(
        "a broken declaration in params is reported where it is, wherever params is written",
        arguments: [
            (#"{ "clip": { "type": "videoo" } }"#, #"params.clip.type (parameter): unknown value "videoo". Allowed: video, sequence, image, audio, text, color, number, choice"#),
            (#"{ "clip": "video" }"#, #"params.clip (parameter): expected an object (parameter), found "video""#)
        ]
    )
    func reportsBrokenDeclarationFirst(
        parameters: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": { "param": "clip" } } ], "params": \#(parameters) }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test(
        "a shape taken by a choice checks its object with each option's keys, so a box and an arrow together stop",
        arguments: [
            (
                #"{ "kind": "sequence", "params": { "s": { "type": "choice", "options": ["box", "arrow"] } }, "clips": [ { "shape": { "param": "s" }, "area": [0, 0, 10, 10] } ] }"#,
                #"clips[0] (arrow): missing key "side""#
            ),
            (
                #"{ "kind": "sequence", "params": { "s": { "type": "choice", "options": ["box", "arrow"] } }, "clips": [ { "shape": { "param": "s" }, "area": [0, 0, 10, 10], "side": "left" } ] }"#,
                #"clips[0] (box): unknown key "side". Allowed: id, metadata, at, lane, opacity, animation, keyframes, shape, area, track, color, blend"#
            )
        ]
    )
    func checksShapeChoiceWithEachOption(
        text: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(text)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("a shape choice of arrows that names its side passes, with its references taken once")
    func acceptsShapeChoiceOfArrows() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "params": { "s": { "type": "choice", "options": ["arrow"] }, "c": { "type": "color" } },
              "clips": [ { "shape": { "param": "s" }, "area": [0, 0, 10, 10], "side": "left", "color": { "param": "c" } } ] }
            """#)

        // When
        let references = try sut.check(template: document, place: .root)

        // Then
        #expect(references.map(\.name) == ["s", "c"])
    }
}

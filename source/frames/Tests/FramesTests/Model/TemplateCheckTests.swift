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
                "name":  { "type": "text", "default": "Ada", "description": "the name" },
                "tint":  { "type": "color", "default": "#FF0000", "description": "the tint" },
                "size":  { "type": "number", "default": 2, "description": "the size" },
                "tone":  { "type": "choice", "options": ["frames/warm", "frames/cool"], "default": "frames/warm", "description": "colour of the whole clip" }
              },
              "storyline": [ { "kind": "media", "media": { "param": "clip" }, "in": 1, "filter": { "param": "tone" },
                               "connected": [ { "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 100, 40], "fill": { "param": "tint" }, "opacity": { "param": "size" } },
                                              { "kind": "title", "text": { "param": "name" }, "style": "s" } ] } ]
            }
            """##)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a text parameter stands for a whole title and for a run's text, and a choice for a run's style",
        arguments: [
            #"{ "kind": "title", "text": { "param": "name" }, "style": "s" }"#,
            #"{ "kind": "title", "text": [ { "text": { "param": "name" }, "style": { "param": "look" } }, { "text": " and more" } ], "style": "s" }"#
        ]
    )
    func acceptsRunParameters(clip: String) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence",
              "params": { "name": { "type": "text", "description": "the name" }, "look": { "type": "choice", "options": ["name", "role"], "default": "name", "description": "the look" } },
              "clips": [ \#(clip), { "kind": "title", "text": "x", "style": { "param": "look" } } ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test("a media parameter's type picks the media row")
    func picksRowByParameterType() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "params": { "card": { "type": "image", "description": "the card" } },
              "storyline": [ { "kind": "media", "media": { "param": "card" }, "in": 1 } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[0] (image): unknown key "in". Allowed: id, metadata, kind, media, colorSpace, toneMap, duration, crop, filter, transition, anchor, position, scale, rotation, cornerPin, opacity, blend, motionBlur, mask, trackMatte, radius, border, shadow, keyframes, connected"#)
    }

    @Test(
        "a parameter that cannot stand where it is written stops",
        arguments: [
            (#"{ "name": { "type": "text", "description": "the name" } }"#, #"{ "kind": "title", "text": "x", "style": { "param": "name" } }"#,
             #"clips[0].style (title): parameter "name" of type text cannot stand where a string is expected"#),
            (#"{ "size": { "type": "number", "description": "the size" } }"#, #"{ "kind": "title", "text": { "param": "size" }, "style": "s" }"#,
             #"clips[0].text (title): parameter "size" of type number cannot stand where a string or a list of runs is expected"#),
            (#"{ "name": { "type": "text", "description": "the name" } }"#, #"{ "kind": "media", "media": { "param": "name" } }"#,
             #"clips[0].media (clip): parameter "name" of type text cannot stand where a media reference is expected"#),
            (#"{ "name": { "type": "text", "description": "the name" } }"#, #"{ "kind": "rect", "stroke": { "width": 8 }, "area": { "param": "name" } }"#,
             #"clips[0].area (rect): parameter "name" of type text cannot stand where an area is expected"#),
            (#"{ "where": { "type": "choice", "options": ["top", "middle"], "description": "the where" } }"#, #"{ "kind": "title", "text": "x", "style": "s", "placement": { "param": "where" } }"#,
             #"clips[0].placement (title): unknown value "middle". Allowed: top-left, top, top-right, left, center, right, bottom-left, bottom, bottom-right"#),
            (#"{ "name": { "type": "text", "description": "the name" } }"#, #"{ "kind": "title", "text": { "param": "nam" }, "style": "s" }"#,
             #"clips[0].text (title): parameter "nam" is not declared in params"#),
            (#"{ "name": { "type": "text", "description": "the name" } }"#, #"{ "kind": "title", "text": [ { "text": "x", "style": { "param": "name" } } ], "style": "s" }"#,
             #"clips[0].text[0].style (run): parameter "name" of type text cannot stand where a string is expected"#)
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
        let document = try Fixture.json(#"{ "kind": "sequence", "params": { "name": { "type": "text", "description": "the name" } }, "clips": [] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"params.name (parameter): "name" is declared but nothing refers to it"#)
    }

    @Test(
        "a parameter takes only its own keys, a description, and options only as a choice",
        arguments: [
            (#"{ "type": "text", "options": ["a", "b"], "description": "d" }"#, #"params.p (parameter): unknown key "options". Allowed: type, default, description"#),
            (#"{ "type": "choice", "description": "d" }"#, #"params.p (parameter): missing key "options""#),
            (#"{ "type": "choice", "options": [], "description": "d" }"#, #"params.p.options (parameter): a choice offers at least two distinct options"#),
            (#"{ "type": "choice", "options": ["a"], "description": "d" }"#, #"params.p.options (parameter): a choice offers at least two distinct options"#),
            (#"{ "type": "choice", "options": ["a", "a"], "description": "d" }"#, #"params.p.options (parameter): a choice offers at least two distinct options"#),
            (#"{ "type": "text" }"#, #"params.p (parameter): missing key "description""#),
            (#"{ "type": "font", "description": "d" }"#, #"params.p.type (parameter): unknown value "font". Allowed: video, sequence, image, audio, text, color, number, choice"#),
            (#"{ "type": "number", "default": "2", "description": "d" }"#, #"params.p.default (parameter): expected a number, found "2""#),
            (#"{ "type": "choice", "options": ["a", "b"], "default": "c", "description": "d" }"#, #"params.p.default (parameter): unknown value "c". Allowed: a, b"#),
            (#"{ "default": 1, "description": "d" }"#, #"params.p (parameter): missing key "type""#),
            (#"{ "type": "text", "label": "x", "description": "d" }"#, #"params.p (parameter): unknown key "label". Allowed: type, default, description, options"#)
        ]
    )
    func checksParameterKeys(
        parameter: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "params": { "p": \#(parameter) }, "clips": [ { "kind": "title", "text": { "param": "p" }, "style": "s" } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test("a template instance takes template and args")
    func checksTemplateInstance() throws {
        // Given
        let compound = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": { "kind": "template", "template": "pack/intro", "args": { "name": "Ada" } }, "in": 0, "out": 3 } ] }"#)
        let unknownKey = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": { "kind": "template", "template": "pack/intro", "arguments": {} } } ] }"#)

        // When, Then
        try sut.check(document: compound)
        let error = #expect(throws: ModelError.self) { try sut.check(document: unknownKey) }
        #expect(error?.description == #"storyline[0].media (template instance): unknown key "arguments". Allowed: kind, template, args"#)
    }

    @Test("a document with params used anywhere but as a template instance stops")
    func refusesNestedTemplate() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": { "kind": "sequence", "params": {}, "storyline": [] }, "in": 0, "out": 1 } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == "storyline[0].media (sequence): a document with params is a template and is used only as a template instance")
    }

    @Test("a document given as an argument is checked like any document")
    func checksDocumentArgument() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": { "kind": "template", "template": "pack/intro", "args": { "shot": { "kind": "sequence", "storyline": [], "opz": [] } } } } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == #"storyline[0].media.args.shot (sequence): unknown key "opz". Allowed: kind, format, theme, params, storyline, clips, audioFilter, keyframes"#)
    }

    @Test("a template named by a choice parameter takes the probed kind its options share")
    func readsTemplateNamedByChoice() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "params": { "t": { "type": "choice", "options": ["pack/intro", "pack/outro"], "description": "the t" } },
              "storyline": [ { "kind": "media", "media": { "kind": "template", "template": { "param": "t" }, "args": {} }, "in": 0, "out": 2 } ] }
            """#)
        let checker = KeyChecker(mediaKinds: MediaKindTable(templates: ["pack/intro", "pack/outro"]))

        // When, Then
        try checker.check(document: document)
    }

    @Test("a parameter used only inside a template instance given as an argument counts as used")
    func recordsParameterInsideArgumentInstance() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "params": { "p": { "type": "text", "description": "the p" } },
              "storyline": [ { "kind": "media", "media": { "kind": "template", "template": "pack/intro", "args": { "x": { "kind": "template", "template": "pack/card", "args": { "y": { "param": "p" } } } } } } ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test("a media object given as an argument is checked like any media")
    func checksMediaArgument() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": { "kind": "template", "template": "pack/intro", "args": { "frames": { "kind": "imageSequence", "directory": "/abs/frames" } } } } ] }
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
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": { "param": "clip" } } ], "params": \#(parameters) }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    @Test(
        "a shape taken by a choice checks its object with each option's keys, so a rect and a path together stop",
        arguments: [
            (
                #"{ "kind": "sequence", "params": { "s": { "type": "choice", "options": ["rect", "path"], "description": "the s" } }, "clips": [ { "kind": { "param": "s" }, "area": [0, 0, 10, 10], "fill": "accent" } ] }"#,
                #"clips[0] (path): unknown key "area". Allowed: id, metadata, kind, at, lane, parent, opacity, blend, motionBlur, mask, trackMatte, track, animation, keyframes, style, position, anchor, fill, stroke, trim, shadow, scale, rotation, points, closed"#
            ),
            (
                #"{ "kind": "sequence", "params": { "s": { "type": "choice", "options": ["rect", "path"], "description": "the s" } }, "clips": [ { "kind": { "param": "s" }, "points": [[0, 0], [10, 10]], "fill": "accent" } ] }"#,
                #"clips[0] (rect): unknown key "points". Allowed: id, metadata, kind, at, lane, parent, opacity, blend, motionBlur, mask, trackMatte, track, animation, keyframes, style, position, anchor, fill, stroke, trim, shadow, scale, rotation, area, width, height, placement, radius, outset, cornerPin"#
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

    @Test(
        "a mask shape taken by a choice checks the mask with each option's keys and geometry",
        arguments: [
            (
                #"{ "kind": { "param": "s" }, "area": [0, 0, 10, 10] }"#,
                #"["rect", "path"]"#,
                #"clips[0].mask (path mask): unknown key "area""#
            ),
            (
                #"{ "kind": { "param": "s" }, "points": [[0, 0]] }"#,
                #"["path", "rect"]"#,
                "clips[0].mask.points (path mask): expected a list of at least two vertices, each [x, y] or {vertex, inTangent, outTangent}"
            ),
            (
                #"{ "kind": { "param": "s" }, "feather": 2 }"#,
                #"["rect", "ellipse"]"#,
                "clips[0].mask (rect mask): needs one of area, width, height, position"
            ),
            (
                #"{ "kind": { "param": "s" }, "area": [0, 0, 10, 10], "width": 10 }"#,
                #"["ellipse", "rect"]"#,
                #"clips[0].mask (ellipse mask): takes only one of "area", "width""#
            )
        ]
    )
    func checksMaskShapeChoiceWithEachOption(
        mask: String,
        options: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "params": { "s": { "type": "choice", "options": \#(options), "description": "the s" } },
              "clips": [ { "kind": "adjustment", "adjust": "frames/vivid", "at": [0, 1], "mask": \#(mask) } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(template: document, place: .root) }
        #expect(error?.description.hasPrefix(message) == true, "\(error?.description ?? "no error")")
    }

    @Test("a mask shape choice of a rect and an ellipse given by an area passes, with its reference taken once")
    func acceptsMaskShapeChoiceOfBoxShapes() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "params": { "s": { "type": "choice", "options": ["rect", "ellipse"], "description": "the s" } },
              "clips": [ { "kind": "adjustment", "adjust": "frames/vivid", "at": [0, 1], "mask": { "kind": { "param": "s" }, "area": [0, 0, 10, 10] } } ] }
            """#)

        // When
        let references = try sut.check(template: document, place: .root)

        // Then
        #expect(references.map(\.name) == ["s"])
    }

    @Test("a shape choice of a rect and an ellipse given by an area passes, with its references taken once")
    func acceptsShapeChoiceOfBoxShapes() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "params": { "s": { "type": "choice", "options": ["rect", "ellipse"], "description": "the s" }, "c": { "type": "color", "description": "the c" } },
              "clips": [ { "kind": { "param": "s" }, "area": [0, 0, 10, 10], "fill": { "param": "c" } } ] }
            """#)

        // When
        let references = try sut.check(template: document, place: .root)

        // Then
        #expect(references.map(\.name) == ["s", "c"])
    }
}

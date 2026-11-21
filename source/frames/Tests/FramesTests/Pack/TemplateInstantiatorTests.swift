//
//  TemplateInstantiatorTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("TemplateInstantiator Tests")
struct TemplateInstantiatorTests {
    // MARK: - Property
    private let sut = TemplateInstantiator(mediaKinds: Fixture.library)
    private let place = Place(components: [.key("storyline"), .index(0, id: nil), .key("media"), .key("args")])
    private let template = ##"""
        { "kind": "sequence",
          "params": {
            "clip":  { "type": "video", "description": "the clip" },
            "title": { "type": "text", "default": "New feature", "description": "the title" },
            "tone":  { "type": "choice", "options": ["frames/warm", "frames/cool"], "default": "frames/warm", "description": "the tone" },
            "tint":  { "type": "color", "default": "#FF0000", "description": "the tint" },
            "size":  { "type": "number", "default": 1, "description": "the size" }
          },
          "storyline": [ { "media": { "param": "clip" }, "filter": { "param": "tone" },
                           "connected": [ { "title": { "param": "title" }, "style": "title" },
                                          { "shape": "rect", "stroke": { "width": 8 }, "area": { "text": "Send" }, "fill": { "param": "tint" }, "opacity": { "param": "size" } } ] } ] }
        """##

    // MARK: - Initializer
    // MARK: - Test
    @Test("every reference takes its argument or its default, and params go, so the instance holds plain values")
    func fillsArguments() throws {
        // Given
        let template = try template(template)
        let arguments = try Fixture.object(#"{ "clip": "/abs/run.mp4", "tone": "frames/cool", "size": 0.5 }"#)

        // When
        let instance = try sut.instance(of: template, arguments: arguments, place: place)

        // Then
        let expected = try Fixture.json(##"""
            { "kind": "sequence",
              "storyline": [ { "media": "/abs/run.mp4", "filter": "frames/cool",
                               "connected": [ { "title": "New feature", "style": "title" },
                                              { "shape": "rect", "stroke": { "width": 8 }, "area": { "text": "Send" }, "fill": "#FF0000", "opacity": 0.5 } ] } ] }
            """##)
        #expect(instance.document == expected)
        #expect(instance.arguments.map(\.place) == [Place(components: [.key("storyline"), .index(0, id: nil), .key("media")])])
        #expect(instance.arguments.map(\.name) == ["clip"])
    }

    @Test("an argument the template does not declare stops")
    func refusesUnknownArgument() throws {
        // Given
        let template = try template(template)
        let arguments = try Fixture.object(##"{ "clip": "/abs/run.mp4", "colour": "#000000" }"##)

        // When, Then
        let error = #expect(throws: ParameterError.self) { try sut.instance(of: template, arguments: arguments, place: place) }
        #expect(error?.description == #"storyline[0].media.args (template arguments): unknown argument "colour". Allowed: clip, title, tone, tint, size"#)
    }

    @Test("a missing argument without a default stops")
    func refusesMissingArgument() throws {
        // Given
        let template = try template(template)

        // When, Then
        let error = #expect(throws: ParameterError.self) { try sut.instance(of: template, arguments: JSONObject(), place: place) }
        #expect(error?.description == #"storyline[0].media.args (template arguments): missing argument "clip", which has no default"#)
    }

    @Test(
        "an argument of the wrong type stops where it is written",
        arguments: [
            (#"{ "clip": "/abs/run.mp4", "title": 3 }"#, "args.title (template arguments): expected a string, found 3"),
            (#"{ "clip": "/abs/run.mp4", "size": "big" }"#, #"args.size (template arguments): expected a number, found "big""#),
            (#"{ "clip": "/abs/run.mp4", "tint": 5 }"#, "args.tint (template arguments): expected a colour, found 5"),
            (#"{ "clip": "/abs/run.mp4", "tone": "hot" }"#, #"args.tone (template arguments): unknown value "hot". Allowed: frames/warm, frames/cool"#),
            (#"{ "clip": 4 }"#, "args.clip (template arguments): expected a media reference, found 4"),
            (#"{ "clip": "/abs/card.png" }"#, #"args.clip (template arguments): parameter "clip" takes video media, found image"#),
            (#"{ "clip": "/abs/bgm.m4a" }"#, #"args.clip (template arguments): parameter "clip" takes video media, found audio"#),
            (#"{ "clip": "/abs/missing.mp4" }"#, #"args.clip (template arguments): media "/abs/missing.mp4" is not there"#)
        ]
    )
    func refusesWrongType(text: String, message: String) throws {
        // Given
        let template = try template(template)
        let arguments = try Fixture.object(text)

        // When, Then
        let error = #expect(throws: (any Error).self) { try sut.instance(of: template, arguments: arguments, place: place) }
        #expect(error.map { "\($0)" } == "storyline[0].media.\(message)")
    }

    @Test("an image sequence is a video argument")
    func takesImageSequenceAsVideo() throws {
        // Given
        let template = try template(template)
        let arguments = try Fixture.object(#"{ "clip": { "imageSequence": "/abs/frames", "fps": 12 } }"#)

        // When
        let instance = try sut.instance(of: template, arguments: arguments, place: place)

        // Then
        let media = instance.document.objectValue?["storyline"]?.arrayValue?[0].objectValue?["media"]
        #expect(media == (try Fixture.json(#"{ "imageSequence": "/abs/frames", "fps": 12 }"#)))
    }

    @Test("a default media of another kind than its parameter stops at the default in the template")
    func refusesDefaultOfWrongKind() throws {
        // Given
        let template = try template(#"""
            { "kind": "sequence", "params": { "clip": { "type": "video", "default": "/abs/card.png", "description": "the clip" } },
              "storyline": [ { "media": { "param": "clip" } } ] }
            """#)

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.instance(of: template, arguments: JSONObject(), place: place) }
        #expect(error?.description == #"shorts/leak: params.clip.default (parameter): parameter "clip" takes video media, found image"#)
    }

    @Test(
        "a value its place cannot take stops at that place in the template, as the same value written there would",
        arguments: [
            (
                #"{ "p": { "type": "number", "description": "the p" } }, "clips": [ { "title": "x", "style": "title", "at": [0, 1], "width": { "param": "p" } } ]"#,
                #"{ "p": -5 }"#,
                "clips[0].width (title): -5 is not above 0"
            ),
            (
                #"{ "p": { "type": "number", "description": "the p" } }, "clips": [ { "title": "x", "style": "title", "at": [0, 1], "lane": { "param": "p" } } ]"#,
                #"{ "p": 0.5 }"#,
                "clips[0].lane (title): expected a whole number, found 0.5"
            ),
            (
                #"{ "p": { "type": "number", "description": "the p" } }, "clips": [ { "title": "x", "style": "title", "at": [0, 1], "width": { "param": "p" }, "lane": { "param": "p" } } ]"#,
                #"{ "p": 0.5 }"#,
                "clips[0].lane (title): expected a whole number, found 0.5"
            ),
            (
                #"{ "w": { "type": "number", "description": "the w" } }, "storyline": [ { "media": "/abs/run.mp4", "crop": [0, 0, { "param": "w" }, 10] } ]"#,
                #"{ "w": 0 }"#,
                "storyline[0].crop[2] (video): 0 is not above 0"
            )
        ]
    )
    func refusesValueItsPlaceCannotTake(parameters: String, text: String, message: String) throws {
        // Given
        let template = try template(#"{ "kind": "sequence", "params": \#(parameters) }"#)
        let arguments = try Fixture.object(text)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.instance(of: template, arguments: arguments, place: place) }
        #expect(error?.description == "shorts/leak: \(message)")
    }

    @Test("a look length given as a parameter stops outside its domain at that place, as a written one does")
    func refusesLookLengthOutsideDomain() throws {
        // Given
        let template = try template(#"""
            { "kind": "sequence", "params": { "p": { "type": "number", "default": -1, "description": "the p" } },
              "clips": [ { "media": "/abs/page.png", "at": [0, 1], "radius": { "param": "p" } } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.instance(of: template, arguments: JSONObject(), place: place) }
        #expect(error?.description == "shorts/leak: clips[0].radius (image): -1 is not 0 or more")
    }

    @Test("a crop scale given as a parameter stops at 0, as a written one does")
    func refusesCropScaleOfZero() throws {
        // Given
        let template = try template(#"""
            { "kind": "sequence", "params": { "s": { "type": "number", "description": "the s" } },
              "storyline": [ { "media": "/abs/run.mp4", "crop": { "scale": { "param": "s" } } } ] }
            """#)
        let arguments = try Fixture.object(#"{ "s": 0 }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.instance(of: template, arguments: arguments, place: place) }
        #expect(error?.description == "shorts/leak: storyline[0].crop.scale (crop): 0 is not above 0")
    }

    @Test("a value that every place of its parameter takes fills them all")
    func fillsPlacesOfDifferentTypes() throws {
        // Given
        let template = try template(#"""
            { "kind": "sequence", "params": { "p": { "type": "number", "description": "the p" } },
              "storyline": [ { "media": "/abs/run.mp4", "crop": { "scale": { "param": "p" } } } ],
              "clips": [ { "title": "x", "style": "title", "at": [0, 1], "lane": { "param": "p" } } ] }
            """#)
        let arguments = try Fixture.object(#"{ "p": 2 }"#)

        // When
        let instance = try sut.instance(of: template, arguments: arguments, place: place)

        // Then
        let expected = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "crop": { "scale": 2 } } ],
              "clips": [ { "title": "x", "style": "title", "at": [0, 1], "lane": 2 } ] }
            """#)
        #expect(instance.document == expected)
    }

    @Test("media given as an argument is recorded where it stands, and a default is not")
    func recordsGivenMedia() throws {
        // Given
        let template = try template(#"""
            { "kind": "sequence",
              "params": { "a": { "type": "video", "description": "the a" }, "b": { "type": "video", "default": "/abs/run.mp4", "description": "the b" } },
              "storyline": [ { "media": { "param": "a" } }, { "media": { "param": "b" } }, { "media": { "param": "a" } } ] }
            """#)
        let arguments = try Fixture.object(#"{ "a": "/abs/short.mp4" }"#)

        // When
        let instance = try sut.instance(of: template, arguments: arguments, place: place)

        // Then
        #expect(instance.arguments.map(\.place.description) == ["storyline[0].media", "storyline[2].media"])
    }

    @Test(
        "an image parameter takes every still, an image or a page of a PDF",
        arguments: [#""/abs/card.png""#, #""/abs/logo.pdf""#, #"{ "file": "/abs/deck.pdf", "page": 4 }"#]
    )
    func takesPageAsImage(argument: String) throws {
        // Given
        let template = try template(stillTemplate)
        let arguments = try Fixture.object(#"{ "still": \#(argument) }"#)

        // When
        let instance = try sut.instance(of: template, arguments: arguments, place: place)

        // Then
        let media = instance.document.objectValue?["storyline"]?.arrayValue?[0].objectValue?["media"]
        #expect(media == (try Fixture.json(argument)))
    }

    @Test("a video parameter takes no page of a PDF")
    func refusesPageAsVideo() throws {
        // Given
        let template = try template(template)
        let arguments = try Fixture.object(#"{ "clip": { "file": "/abs/deck.pdf", "page": 4 } }"#)

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.instance(of: template, arguments: arguments, place: place) }
        #expect(error?.description == #"storyline[0].media.args.clip (template arguments): parameter "clip" takes video media, found page"#)
    }

    @Test("a PDF of several pages named as a file stops at the parameter type check, naming its page count")
    func refusesPdfOfSeveralPagesAsArgument() throws {
        // Given
        let template = try template(stillTemplate)
        let arguments = try Fixture.object(#"{ "still": "/abs/deck.pdf" }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.instance(of: template, arguments: arguments, place: place) }
        #expect(error?.description == #"storyline[0].media.args.still (template arguments): media "/abs/deck.pdf" is a PDF of 12 pages, more than one picture, so a page of it is named as {"file", "page"}"#)
    }

    @Test(
        "an image parameter given a page makes its clips clips of a page, so toneMap and an HDR colorSpace on them stop",
        arguments: [
            (
                #""toneMap": false"#,
                #"shorts/leak: storyline[0] (page): unknown key "toneMap""#
            ),
            (
                #""colorSpace": "rec2100-pq""#,
                #"shorts/leak: storyline[0].colorSpace (page): unknown value "rec2100-pq""#
            )
        ]
    )
    func refusesHighDynamicRangeKeysOnPageArgument(key: String, message: String) throws {
        // Given
        let template = try template(stillTemplate(key: key))
        let arguments = try Fixture.object(#"{ "still": { "file": "/abs/deck.pdf", "page": 4 } }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.instance(of: template, arguments: arguments, place: place) }
        #expect(error?.description.hasPrefix(message) == true)
    }

    @Test("an image parameter given an image keeps the still row, toneMap and an HDR colorSpace included")
    func takesHighDynamicRangeKeysOnImageArgument() throws {
        // Given
        let template = try template(stillTemplate(key: #""toneMap": false, "colorSpace": "rec2100-pq""#))
        let arguments = try Fixture.object(#"{ "still": "/abs/card.png" }"#)

        // When
        let instance = try sut.instance(of: template, arguments: arguments, place: place)

        // Then
        #expect(instance.document.objectValue?["storyline"]?.arrayValue?[0].objectValue?["toneMap"] == .bool(false))
    }

    @Test("a connected clip whose image parameter is given a one-page PDF stops at toneMap")
    func refusesToneMapOnConnectedPageArgument() throws {
        // Given
        let template = try template(#"""
            { "kind": "sequence", "params": { "still": { "type": "image", "description": "the still" } },
              "storyline": [ { "solid": "#000000", "duration": 2,
                "connected": [ { "media": { "param": "still" }, "toneMap": true } ] } ] }
            """#)
        let arguments = try Fixture.object(#"{ "still": "/abs/logo.pdf" }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.instance(of: template, arguments: arguments, place: place) }
        #expect(error?.description.hasPrefix(#"shorts/leak: storyline[0].connected[0] (page): unknown key "toneMap""#) == true)
    }

    // MARK: - Private
    private func stillTemplate(key: String) -> String {
        #"""
        { "kind": "sequence", "params": { "still": { "type": "image", "description": "the still" } },
          "storyline": [ { "media": { "param": "still" }, "duration": 2, \#(key) } ] }
        """#
    }

    private var stillTemplate: String {
        #"""
        { "kind": "sequence", "params": { "still": { "type": "image", "description": "the still" } },
          "storyline": [ { "media": { "param": "still" }, "duration": 2 } ] }
        """#
    }

    private func template(_ text: String) throws -> Template {
        try TemplateReader(mediaKinds: Fixture.library)
            .template(from: Fixture.json(text), place: Place(file: "shorts/leak", components: []))
    }
}

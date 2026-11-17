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
            "clip":  { "type": "video" },
            "title": { "type": "text", "default": "New feature" },
            "tone":  { "type": "choice", "options": ["frames/warm", "frames/cool"], "default": "frames/warm" },
            "tint":  { "type": "color", "default": "#FF0000" },
            "size":  { "type": "number", "default": 1 }
          },
          "storyline": [ { "media": { "param": "clip" }, "filter": { "param": "tone" },
                           "connected": [ { "title": { "param": "title" }, "style": "title" },
                                          { "shape": "box", "area": "Send", "color": { "param": "tint" }, "opacity": { "param": "size" } } ] } ] }
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
                                              { "shape": "box", "area": "Send", "color": "#FF0000", "opacity": 0.5 } ] } ] }
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
        let error = #expect(throws: PackError.self) { try sut.instance(of: template, arguments: arguments, place: place) }
        #expect(error?.description == #"storyline[0].media.args (template arguments): unknown argument "colour". Allowed: clip, title, tone, tint, size"#)
    }

    @Test("a missing argument without a default stops")
    func refusesMissingArgument() throws {
        // Given
        let template = try template(template)

        // When, Then
        let error = #expect(throws: PackError.self) { try sut.instance(of: template, arguments: JSONObject(), place: place) }
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
            { "kind": "sequence", "params": { "clip": { "type": "video", "default": "/abs/card.png" } },
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
                #"{ "p": { "type": "number" } }, "clips": [ { "title": "x", "style": "title", "at": [0, 1], "width": { "param": "p" } } ]"#,
                #"{ "p": -5 }"#,
                "clips[0].width (title): expected a number above 0, found -5"
            ),
            (
                #"{ "p": { "type": "number" } }, "clips": [ { "title": "x", "style": "title", "at": [0, 1], "lane": { "param": "p" } } ]"#,
                #"{ "p": 0.5 }"#,
                "clips[0].lane (title): expected a whole number, found 0.5"
            ),
            (
                #"{ "p": { "type": "number", "default": -1 } }, "clips": [ { "media": "/abs/page.png", "at": [0, 1], "radius": { "param": "p" } } ]"#,
                "{}",
                "clips[0].radius (image): expected a number, 0 or more, found -1"
            ),
            (
                #"{ "p": { "type": "number" } }, "clips": [ { "title": "x", "style": "title", "at": [0, 1], "width": { "param": "p" }, "lane": { "param": "p" } } ]"#,
                #"{ "p": 0.5 }"#,
                "clips[0].lane (title): expected a whole number, found 0.5"
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

    @Test("a crop scale given as a parameter stops at 0, as a written one does")
    func refusesCropScaleOfZero() throws {
        // Given
        let template = try template(#"""
            { "kind": "sequence", "params": { "s": { "type": "number" } },
              "storyline": [ { "media": "/abs/run.mp4", "crop": { "scale": { "param": "s" } } } ] }
            """#)
        let arguments = try Fixture.object(#"{ "s": 0 }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.instance(of: template, arguments: arguments, place: place) }
        #expect(error?.description == "shorts/leak: storyline[0].crop.scale (crop): expected a number above 0, found 0")
    }

    @Test("a value that every place of its parameter takes fills them all")
    func fillsPlacesOfDifferentTypes() throws {
        // Given
        let template = try template(#"""
            { "kind": "sequence", "params": { "p": { "type": "number" } },
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

    @Test(
        "a shape choice of arrows that names its side fills the shape picked and keeps the side",
        arguments: [
            (
                #"{ "kind": "sequence", "params": { "s": { "type": "choice", "options": ["arrow"] } }, "clips": [ { "shape": { "param": "s" }, "area": [0, 0, 10, 10], "side": "top" } ] }"#,
                #"{ "kind": "sequence", "clips": [ { "shape": "arrow", "area": [0, 0, 10, 10], "side": "top" } ] }"#
            )
        ]
    )
    func fillsShapeChoiceOfArrows(text: String, filled: String) throws {
        // Given
        let template = try template(text)
        let arguments = try Fixture.object(#"{ "s": "arrow" }"#)

        // When
        let instance = try sut.instance(of: template, arguments: arguments, place: place)

        // Then
        #expect(instance.document == (try Fixture.json(filled)))
    }

    @Test("media given as an argument is recorded where it stands, and a default is not")
    func recordsGivenMedia() throws {
        // Given
        let template = try template(#"""
            { "kind": "sequence",
              "params": { "a": { "type": "video" }, "b": { "type": "video", "default": "/abs/run.mp4" } },
              "storyline": [ { "media": { "param": "a" } }, { "media": { "param": "b" } }, { "media": { "param": "a" } } ] }
            """#)
        let arguments = try Fixture.object(#"{ "a": "/abs/short.mp4" }"#)

        // When
        let instance = try sut.instance(of: template, arguments: arguments, place: place)

        // Then
        #expect(instance.arguments.map(\.place.description) == ["storyline[0].media", "storyline[2].media"])
    }

    // MARK: - Private
    private func template(_ text: String) throws -> Template {
        try TemplateReader(mediaKinds: Fixture.library)
            .template(from: Fixture.json(text), place: Place(file: "shorts/leak", components: []))
    }
}

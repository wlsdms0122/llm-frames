//
//  ResolvedDocumentReaderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("ResolvedDocumentReader Tests")
struct ResolvedDocumentReaderTests {
    // MARK: - Property
    private let sut = ResolvedDocumentReader()
    private let writer = ResolvedDocumentWriter()

    // A transition with spans, a video cover and a still matte, and a filter with a LUT.
    private static let presets = PresetTable(
        transitions: Fixture.presets.transitions.merging([
            "reveal": TransitionPreset(
                description: "",
                seconds: 1,
                over: .incoming,
                incoming: Span(ease: .easeOut, keys: [SpanKey(t: 0, values: [.scale: 1.2, .opacity: 0]), SpanKey(t: 1, values: [:])]),
                outgoing: nil,
                cover: Cover(source: .media("/abs/leak.mov"), span: Span(ease: .linear, keys: [])),
                matte: Matte(media: "/abs/matte.png", softness: 0.1, isInverted: true, ease: .cubicBezier(x1: 0.3, y1: 0, x2: 0.2, y2: 1))
            ),
            "dip": TransitionPreset(
                description: "",
                seconds: 1,
                over: .outgoing,
                incoming: nil,
                outgoing: Span(ease: .linear, revealFrom: .top, keys: [SpanKey(t: 0, values: [.y: 0]), SpanKey(t: 1, values: [.y: 1])]),
                cover: Cover(source: .color("#FFFFFF"), span: Span(ease: .linear, keys: [SpanKey(t: 0.5, values: [.opacity: 1])])),
                matte: nil
            )
        ]) { $1 },
        animations: Fixture.presets.animations,
        filters: Fixture.presets.filters.merging([
            "film": FilterPreset(description: "", operations: [
                .lut(file: "/abs/film.cube", amount: 0.5),
                .bloom(amount: 0.5, radius: 4, color: "#FFFFFF"),
                .levels(input: [0, 1], output: [0.1, 0.9])
            ])
        ]) { $1 }
    )

    // Documents that between them write every kind of resolved entry and value.
    private static let documents = [
        // A cropped, filtered storyline clip at speed 2, a title that pops in, a picture with a border and music.
        #"""
        { "kind": "sequence", "format": { "size": [1080, 1920], "inset": [40, 40, 500, 40] },
          "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2, "filter": "grade",
                           "keyframes": [ { "at": 2, "crop": [0, 0, 1080, 1920] }, { "at": 8, "crop": [45, 97, 990, 1760] } ] } ],
          "clips": [ { "title": "Hi", "style": "label", "at": [0, 3], "animation": "pop", "position": [75.4, 1709.8] },
                     { "media": "/abs/page.png", "at": [0, 3], "width": 200, "border": true, "shadow": true, "radius": 12 },
                     { "media": "/abs/bgm.m4a", "at": 0, "loop": true,
                       "keyframes": [ { "at": 0, "volume": 0.3 }, { "at": 2, "volume": 0.3 }, { "at": 3, "volume": 0 } ] } ] }
        """#,
        // A solid, an image sequence, a nested sequence, transitions with a cover and a matte, and a LUT.
        #"""
        { "kind": "sequence", "storyline": [
            { "solid": "accent", "duration": 2 },
            { "media": { "imageSequence": "/abs/frames", "fps": 12 }, "filter": "film", "transition": "reveal" },
            { "media": { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 2 } ] }, "transition": "dip" } ] }
        """#,
        // Shapes with labels, a tracked area and a band, an adjustment, a timed media clip and sound with fades.
        #"""
        { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "in": 1, "out": 3, "fadeIn": 0.5, "connected": [
            { "shape": "box", "area": "Total", "track": "Total", "label": "a", "labelAnimation": "fade" },
            { "shape": "fill", "area": { "band": "Total" }, "track": true },
            { "shape": "arrow", "side": "left", "area": [500, 500, 100, 100], "at": [1, 2], "label": "b", "lane": -1 },
            { "shape": "dim", "area": [0, 0, 100, 100], "at": [1, 2], "id": "dim" },
            { "adjust": "grade", "area": [0, 0, 10, 10], "at": [1, 2] },
            { "media": "/abs/short.mp4", "in": 1, "out": 3, "speed": 2, "at": 1, "width": 300, "conform": "fill",
              "keyframes": [ { "at": 1, "opacity": 0, "ease": "ease-in" }, { "at": 1.5, "opacity": 1 } ] },
            { "media": "/abs/ding.wav", "at": 1.5, "fadeIn": 0.25, "fadeOut": 0.5 } ] } ] }
        """#,
        // An image with a crop, a resize, a pad, every shape, a title, adjustments and a border.
        #"""
        { "kind": "image", "source": "/abs/page.png",
          "ops": [ { "crop": [100, 100, 400, 200] }, { "resize": { "width": 800 } }, { "pad": 20 },
                   { "shape": "box", "area": [150, 150, 100, 50] }, { "shape": "dim", "area": [120, 120, 50, 50] },
                   { "shape": "arrow", "side": "left", "area": [300, 150, 50, 50] },
                   { "title": "Hi", "style": "label", "position": [200, 150] },
                   { "adjust": "grade" }, { "adjust": "grade", "area": [110, 110, 10, 10] }, { "border": true } ] }
        """#,
        // A layout with a heading and a nested image.
        #"""
        { "kind": "layout",
          "items": [ { "heading": "Before", "image": "/abs/card.png" }, { "image": { "kind": "image", "source": "/abs/page.png" } } ] }
        """#,
        // An image of a video at a media second, and one of a compound clip's sequence at a time of its own.
        #"""
        { "kind": "layout",
          "items": [ { "image": { "kind": "image", "source": "/abs/short.mp4", "time": 1 } },
                     { "image": { "kind": "image", "time": 1,
                                  "source": { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 2 } ] } } } ] }
        """#
    ]

    private static let boxedImage = #"""
        { "kind": "image", "source": "/abs/page.png", "ops": [ { "shape": "box", "area": [10, 10, 20, 20], "id": "serial" } ] }
        """#

    // MARK: - Initializer
    // MARK: - Test
    @Test("a resolved document reads back to the model it was written from", arguments: documents.indices)
    func readsWrittenDocument(index: Int) throws {
        // Given
        let document = try resolved(Self.documents[index])
        let text = writer.write(document)

        // When
        let read = try sut.read(text)

        // Then
        #expect(read == document)
    }

    @Test(
        "a resolved document from a later minor version or another major version is refused, naming both versions",
        arguments: ["1.1.0", "2.0.0", "0.9.0"]
    )
    func refusesOtherVersion(version: String) throws {
        // Given
        let text = try replacingFirst(#""resolved": "1.0.0""#, with: #""resolved": "\#(version)""#, in: written(Self.documents[3]))

        // When
        let error = #expect(throws: ResolveError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == #"""
            resolved (image): the resolved document was written by frames "\#(version)", and frames 1.0.0 reads only one \#
            written by frames 1.0 up to 1.0
            """#)
    }

    @Test("a document without resolved is not a resolved document")
    func refusesMissingVersion() throws {
        // Given
        let text = #"{ "kind": "image", "size": [1, 1], "steps": [] }"#

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == #"top level (image): missing key "resolved""#)
    }

    @Test(
        "a member that is missing, of another type, or never written there stops, naming its place",
        arguments: [
            (#""in": 2,"#, "", #"storyline[0] (storyline clip): missing key "in""#),
            (#""speed": 2,"#, #""speed": "2","#, #"storyline[0].speed (storyline clip): expected a number, found "2""#),
            (#""at": 0,"#, #""at": [0],"#, #"storyline[0].crop[0].at (storyline clip): expected a number, found a list of 1"#),
            (#""size": [1080, 1920],"#, #""size": [1080],"#, #"format.size (format): expected a list of 2 numbers, found a list of 1"#),
            (
                #""duration": 3,"#,
                #""duration": 3, "fsp": 30,"#,
                #"format (format): unknown key "fsp". Allowed: size, fps, duration, background, content, conform"#
            ),
            (
                #""loop": true,"#,
                #""loop": true, "scale": [],"#,
                #"audio[1] (audio): unknown key "scale". Allowed: place, media, nested, in, origin, out, speed, loop, start, end, audible, volume, fadeIn, fadeOut, incoming, outgoing"#
            )
        ]
    )
    func refusesUnreadableMember(
        written: String,
        replacement: String,
        message: String
    ) throws {
        // Given
        let text = try replacingFirst(written, with: replacement, in: self.written(Self.documents[0]))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("scale and rotation are read only for a title or media clip, and blend for anything but an adjustment")
    func refusesKeyOfAnotherClipKind() throws {
        // Given
        let text = try replacingFirst(#""shape": "dim","#, with: #""shape": "dim", "scale": [],"#, in: written(Self.documents[2]))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description.hasPrefix(#"clips[3] (clip): unknown key "scale""#) == true)
    }

    @Test("a drawing step reads back the place, id and kind of what drew it")
    func readsStepOrigins() throws {
        // Given
        let text = try written(Self.boxedImage)

        // When
        let read = try sut.read(text)

        // Then
        guard case let .picture(picture) = read else {
            Issue.record("the image is read as \(read)")
            return
        }
        #expect(picture.steps.map(\.place) == ["source", "ops[0]#serial"])
        #expect(picture.steps.map(\.id) == [nil, "serial"])
        #expect(picture.steps.map(\.kind) == ["image", "box"])
    }

    @Test(
        "a drawing step without what drew it, or with a key never written there, stops, naming its place",
        arguments: [
            (#""place": "source","#, "", #"steps[0] (drawing step): missing key "place""#),
            (#""id": "serial","#, #""id": 7,"#, #"steps[1].id (drawing step): expected a string, found 7"#),
            (
                #""kind": "box","#,
                #""kind": "box", "label": null,"#,
                #"steps[1] (drawing step): unknown key "label". Allowed: place, id, kind, draw, area, width, radius, color, clip"#
            )
        ]
    )
    func refusesUnreadableStep(
        written: String,
        replacement: String,
        message: String
    ) throws {
        // Given
        let text = try replacingFirst(written, with: replacement, in: self.written(Self.boxedImage))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("a root that is not an object stops")
    func refusesNonObjectRoot() throws {
        // Given
        let text = "[]"

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == "top level (resolved document): expected an object, found a list of 0")
    }

    // MARK: - Private
    private func resolved(_ document: String) throws -> ResolvedDocument {
        let planner = DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: Self.presets,
            ocr: Fixture.ocr,
            tracker: Fixture.tracker,
            shaper: Fixture.shaper,
            library: Fixture.library
        )

        return try ResolvedDocument(plan: planner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    private func written(_ document: String) throws -> String {
        writer.write(try resolved(document))
    }

    private func replacingFirst(
        _ target: String,
        with replacement: String,
        in text: String
    ) -> String {
        guard let range = text.range(of: target) else {
            Issue.record("\(target) is not in the text")
            return text
        }

        return text.replacingCharacters(in: range, with: replacement)
    }
}

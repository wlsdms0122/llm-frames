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
        // A cropped, filtered storyline clip at speed 2, a title that pops in, a still with a border and music.
        #"""
        { "kind": "sequence", "format": { "size": [1080, 1920] },
          "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2, "filter": "mine/grade",
                           "keyframes": [ { "at": 2, "crop": [0, 0, 1080, 1920] }, { "at": 8, "crop": [45, 97, 990, 1760] } ] } ],
          "clips": [ { "title": "Hi", "style": "title", "at": [0, 3], "animation": "frames/pop", "position": [75.4, 1709.8] },
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
        // Shapes, tracked areas with and without padding, an adjustment, a timed media clip, a title parented to a shape and sound
        // with fades.
        #"""
        { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "in": 1, "out": 3, "fadeIn": 0.5, "connected": [
            { "shape": "rect", "stroke": { "width": 8 }, "area": { "text": "Total" }, "parent": "screen", "track": { "text": "Total" } },
            { "shape": "rect", "fill": "#FFD43B80", "area": { "text": "Total", "padding": 14 }, "parent": "screen", "track": true },
            { "shape": "path", "points": [[500, 500], [600, 550]], "stroke": { "width": 10, "end": "arrow" }, "at": [1, 2], "lane": -1 },
            { "shape": "rect", "area": [0, 0, 100, 100], "fill": "#0000008C", "at": [1, 2], "id": "dim" },
            { "adjust": "mine/grade", "mask": { "shape": "rect", "area": [0, 0, 10, 10] }, "at": [1, 2] },
            { "media": "/abs/short.mp4", "in": 1, "out": 3, "speed": 2, "at": 1, "width": 300, "conform": "fill",
              "keyframes": [ { "at": 1, "opacity": 0, "ease": "ease-in" }, { "at": 1.5, "opacity": 1 } ] },
            { "title": "Hi", "style": "title", "at": [1, 2], "parent": "dim", "position": [50, 50] },
            { "media": "/abs/ding.wav", "at": 1.5, "fadeIn": 0.25, "fadeOut": 0.5 } ] } ] }
        """#,
        // Each shape kind and form: a rect by its area with a style, outset and a shadow object, a rect by its width
        // and height keyframed, an ellipse by its box at a position, an ellipse by its area with a named anchor, an
        // open path with keyframed points and trim, and a closed path, scaled and turned.
        ##"""
        { "kind": "sequence",
          "theme": { "shapes": { "outline": { "stroke": { "width": 8, "color": "#ED2929" }, "radius": 18 } } },
          "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 4 } ],
          "clips": [
            { "shape": "rect", "style": "outline", "area": [10, 20, 300, 200], "outset": 6, "shadow": { "radius": 4 }, "at": [0, 4] },
            { "shape": "rect", "fill": "accent", "height": 100, "placement": "top", "at": [0, 4],
              "keyframes": [ { "at": 0, "width": 200, "radius": 4, "ease": "ease-in" }, { "at": 2, "width": 400, "radius": 12 } ] },
            { "shape": "ellipse", "width": 120, "height": 60, "anchor": "top-left", "position": [100, 100], "outset": 2,
              "stroke": { "width": 3, "join": "bevel", "cap": "square" }, "rotation": 30, "at": [0, 4] },
            { "shape": "ellipse", "area": [100, 100, 80, 40], "anchor": "bottom-right", "position": [400, 300], "fill": "#FFFFFF80",
              "shadow": true, "scale": 2, "at": [0, 4] },
            { "shape": "path", "stroke": { "width": 6, "start": "arrow", "end": "arrow", "color": "#00FF00" }, "at": [0, 4],
              "keyframes": [ { "at": 0, "points": [[0, 0], [100, 50], [200, 0]], "trim": [0, 0] },
                             { "at": 1, "points": [[0, 100], [100, 150], [200, 100]], "trim": [0.2, 1], "rotation": 45 } ] },
            { "shape": "path", "points": [[300, 300], [400, 300], [350, 380]], "closed": true, "fill": "accent", "stroke": false,
              "shadow": true, "at": [0, 4] } ] }
        """##
    ]

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
        let text = try replacingFirst(#""resolved": "1.0.0""#, with: #""resolved": "\#(version)""#, in: written(Self.documents[0]))

        // When
        let error = #expect(throws: ResolveError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == #"""
            resolved (sequence): the resolved document was written by frames "\#(version)", and frames 1.0.0 reads only one \#
            written by frames 1.0 up to 1.0
            """#)
    }

    @Test("a document without resolved is not a resolved document")
    func refusesMissingVersion() throws {
        // Given
        let text = #"{ "kind": "sequence", "format": {}, "storyline": [], "clips": [], "audio": [] }"#

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == #"top level (sequence): missing key "resolved""#)
    }

    @Test(
        "a member that is missing, of another type, or never written there stops, naming its place",
        arguments: [
            (#""in": 2,"#, "", #"storyline[0] (storyline clip): missing key "in""#),
            (#""speed": 2,"#, #""speed": "2","#, #"storyline[0].speed (storyline clip): expected a number, found "2""#),
            (#""at": 0,"#, #""at": [0],"#, #"storyline[0].position[0].at (storyline clip): expected a number, found a list of 1"#),
            (#""size": [1080, 1920],"#, #""size": [1080],"#, #"format.size (format): expected a list of 2 numbers, found a list of 1"#),
            (
                #""duration": 3,"#,
                #""duration": 3, "fsp": 30,"#,
                #"format (format): unknown key "fsp". Allowed: size, fps, duration, background, conform"#
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

    @Test("scale, rotation and blend are read for anything drawn, and not for an adjustment")
    func refusesKeyOfAnotherClipKind() throws {
        // Given
        let text = try replacingFirst(#""adjust":"#, with: #""scale": [], "adjust":"#, in: written(Self.documents[2]))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description.hasPrefix(#"clips[4] (clip): unknown key "scale""#) == true)
    }

    @Test(
        "a shape entry's member of the wrong form stops, naming its place",
        arguments: [
            (#""shape": "rect""#, #""shape": "box""#, #"clips[0].shape (clip): unknown value "box". Allowed: rect, ellipse, path"#),
            (#""join": "round""#, #""join": "square""#, #"clips[0].stroke.join (stroke): unknown value "square". Allowed: miter, round, bevel"#),
            (#""end": "none""#, #""end": "dot""#, #"clips[0].stroke.end (stroke): unknown value "dot". Allowed: none, arrow"#),
            (#""cap": "butt""#, #""cap": "butt", "head": 8"#, #"clips[0].stroke (stroke): unknown key "head". Allowed: color, width, join, cap, start, end"#)
        ]
    )
    func refusesShapeMember(
        written: String,
        replacement: String,
        message: String
    ) throws {
        // Given
        let text = try replacingFirst(written, with: replacement, in: self.written(Self.documents[3]))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test(
        "a parent that names no clip with a picture, or a parent chain that comes back to itself, stops",
        arguments: [
            (#""parent": "a""#, #""parent": "ghost""#, #"clips[1].parent (clip): no clip in the document has the id "ghost""#),
            (#""parent": "a""#, #""parent": "sound""#, #"clips[1].parent (clip): no clip in the document has the id "sound""#),
            (
                #""parent": "screen""#,
                #""parent": "b""#,
                #"clips[0].parent (clip): the parent chain comes back to itself: "a" > "b" > "a""#
            )
        ]
    )
    func refusesParent(
        written: String,
        replacement: String,
        message: String
    ) throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "in": 0, "out": 2 } ],
              "clips": [ { "id": "a", "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "screen" },
                         { "id": "b", "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "a" },
                         { "id": "sound", "media": "/abs/bgm.m4a", "at": [0, 1] } ] }
            """#
        let text = try replacingFirst(written, with: replacement, in: self.written(document))

        // When
        let error = #expect(throws: ResolveError.self) { try sut.read(text) }

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
    private func resolved(_ document: String) throws -> ResolvedSequence {
        let planner = DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: Self.presets,
            ocr: Fixture.ocr,
            tracker: Fixture.tracker,
            shaper: Fixture.shaper,
            library: Fixture.library
        )

        return try ResolvedSequence(plan: planner.plan(Fixture.json(document)), hashes: FileHashTable())
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

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

    // A transition with spans, a video cover and a still matte, one that crossfades at constant gain, springs among their
    // eases, and a filter with a LUT.
    private static let presets = PresetTable(
        transitions: Fixture.presets.transitions.merging([
            "reveal": TransitionPreset(
                description: "",
                seconds: 1,
                over: .incoming,
                audio: .constantPower,
                incoming: Span(ease: .easeOut, keys: [SpanKey(t: 0, values: [.scale: 1.2, .opacity: 0]), SpanKey(t: 1, values: [:])]),
                outgoing: nil,
                cover: Cover(source: .media("/abs/leak.mov"), span: Span(ease: .spring(bounce: 0.6), keys: [])),
                matte: Matte(media: "/abs/matte.png", softness: 0.1, isInverted: true, ease: .cubicBezier(x1: 0.3, y1: 0, x2: 0.2, y2: 1))
            ),
            "dip": TransitionPreset(
                description: "",
                seconds: 1,
                over: .outgoing,
                audio: .constantGain,
                incoming: nil,
                outgoing: Span(ease: .spring(bounce: -0.4), revealFrom: .top, keys: [SpanKey(t: 0, values: [.y: 0]), SpanKey(t: 1, values: [.y: 1])]),
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
                       "keyframes": [ { "at": 0, "volume": 0.3, "pan": -0.5, "ease": "ease-in" }, { "at": 2, "volume": 0.3 },
                                      { "at": 3, "volume": 0, "pan": 0.5 } ] } ] }
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
              "keyframes": [ { "at": 1, "opacity": 0, "ease": { "spring": { "bounce": 0.3 } } }, { "at": 1.5, "opacity": 1 } ] },
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
        """##,
        // Masks of each geometry form on a storyline clip, an adjustment, a shape and a title: an area found by text, a
        // box, an area and a path, inverted, feathered, in each mode, static and keyframed.
        #"""
        { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "in": 0, "out": 3,
            "mask": { "shape": "rect", "area": { "text": "Total", "padding": 4 }, "radius": 6, "feather": 2, "invert": true },
            "connected": [
              { "adjust": "mine/grade", "parent": "screen", "mask": [
                  { "shape": "ellipse", "width": 60, "height": 30, "position": [100, 100], "mode": "subtract" },
                  { "shape": "path", "points": [[0, 0], [100, 0], [50, 80]], "mode": "intersect" } ] },
              { "shape": "rect", "fill": "#FF000080", "parent": "screen", "area": [0, 0, 500, 500], "keyframes": [
                  { "at": 0, "ease": "ease-out", "mask": { "shape": "ellipse", "area": { "text": "Total" }, "feather": 1 } },
                  { "at": 2, "mask": { "shape": "ellipse", "area": [0, 0, 50, 50], "feather": 3 } } ] },
              { "title": "Hi", "style": "title", "parent": "screen", "position": [300, 300], "keyframes": [
                  { "at": 0, "mask": { "shape": "path", "points": [[0, 0], [10, 0], [5, 10]] } },
                  { "at": 1, "mask": { "shape": "path", "points": [[0, 0], [20, 0], [10, 20]] } } ] } ] } ] }
        """#,
        // Track mattes: a storyline clip cut by a title's alpha, a still by a shape's inverted luma, and the shape by
        // the title in turn, so the title is the matte of two clips and the end of a chain.
        #"""
        { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "in": 0, "out": 2,
            "trackMatte": { "clip": "word", "mode": "alpha" },
            "connected": [
              { "id": "word", "title": "Hi", "style": "title", "at": [0, 1] },
              { "media": "/abs/page.png", "at": [0, 1], "trackMatte": { "clip": "bar", "mode": "luma", "invert": true } } ] } ],
          "clips": [
            { "id": "bar", "shape": "rect", "fill": "#FFFFFF", "area": [0, 0, 10, 10], "at": [0, 1],
              "trackMatte": { "clip": "word", "mode": "alpha" } },
            { "id": "grade", "adjust": "mine/grade", "at": [0, 1] } ] }
        """#,
        // Time remapping: a storyline clip held, reversed and eased past the end of its media, and a connected media
        // clip remapped over its window, which writes no `in`, `out` or `loop`.
        #"""
        { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "in": 0, "out": 6, "keyframes": [
            { "at": 0, "timeRemap": 1 }, { "at": 1, "timeRemap": 1, "ease": "ease-in" }, { "at": 3, "timeRemap": 0.5 } ],
            "connected": [ { "media": "/abs/short.mp4", "at": [1, 3], "keyframes": [
              { "at": 1, "timeRemap": 3 }, { "at": 3, "timeRemap": 0 } ] } ] } ] }
        """#,
        // A title of runs over two lines with a background, one run in the stroked subtitle style.
        #"""
        { "kind": "sequence", "format": { "size": [1920, 1080] },
          "theme": { "styles": { "card": { "size": 40, "background": { "color": "#000000", "padding": [4, 8], "radius": 6 } } } },
          "storyline": [ { "solid": "#000000", "duration": 2 } ],
          "clips": [ { "title": [ { "text": "Big", "style": "subtitle" }, { "text": " news\nToday" } ], "style": "card",
                       "at": [0, 2], "position": [200, 200] } ] }
        """#
    ]

    // A tracked screen, a shape that follows the screen it is parented to, and a media clip of video under it that
    // follows its own media.
    private static let trackedDocument = #"""
        { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4", "in": 0, "out": 3, "track": { "text": "Total" }, "connected": [
            { "shape": "rect", "stroke": { "width": 8 }, "area": { "text": "Total" }, "parent": "screen", "track": true },
            { "media": "/abs/short.mp4", "parent": "screen", "position": [0, 0], "at": [0, 2], "track": { "text": "Send" } } ] } ] }
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

    @Test("a run's stroke reads back with the run, and a run without one reads back without")
    func readsRunStroke() throws {
        // Given
        let text = try written(Self.documents[Self.documents.count - 1])

        // When
        let read = try sut.read(text)

        // Then
        guard case let .title(title) = read.clips.first?.content else {
            Issue.record("the first clip is not a title")
            return
        }
        #expect(title.runs.map(\.stroke) == [TextStroke(width: 3, color: Color(written: "#000000")), nil, nil])
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
                #"audio[1] (audio): unknown key "scale". Allowed: place, media, nested, in, origin, out, speed, loop, start, end, audible, volume, pan, fadeIn, fadeOut, incoming, outgoing"#
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

    @Test("an `audio` curve that is not a crossfade curve stops on a sound's crossfade, and a storyline transition carries none")
    func refusesUnknownCrossfadeCurve() throws {
        // Given
        let text = try written(Self.documents[1])
        let curve = #""audio": "constant-gain""#
        let last = try #require(text.range(of: curve, options: .backwards))
        let crossfade = text.replacingCharacters(in: last, with: #""audio": "linear""#)
        let transition = replacingFirst(#""over": "#, with: #""audio": "constant-gain", "over": "#, in: text)

        // When
        let crossfadeError = #expect(throws: ModelError.self) { try sut.read(crossfade) }
        let transitionError = #expect(throws: ModelError.self) { try sut.read(transition) }

        // Then
        #expect(crossfadeError?.description == #"audio[0].incoming.audio (crossfade): unknown value "linear". Allowed: constant-power, constant-gain"#)
        #expect(transitionError?.description == #"storyline[1].transition (transition): unknown key "audio". Allowed: start, end, over, incoming, outgoing, cover, matte"#)
    }

    @Test("an adjustment's blend is written, read back as written, and given to the item it draws")
    func keepsAdjustmentBlend() throws {
        // Given
        let text = try written(#"""
            { "kind": "sequence", "format": { "size": [160, 90] },
              "storyline": [ { "media": "/abs/short.mp4", "in": 0, "out": 2 } ],
              "clips": [ { "adjust": "mine/grade", "at": [0, 2], "blend": "screen" } ] }
            """#)

        // When
        let sequence = try sut.read(text)
        let list = Evaluator().displayList(of: sequence, at: 1)

        // Then
        let entry = try JSONReader().read(text).objectValue?["clips"]?.arrayValue?.first?.objectValue
        #expect(entry?["blend"] == .string("screen"))
        #expect(sequence.clips.map(\.blend) == ["screen"])
        #expect(list.items.last?.blend == "screen")
    }

    @Test("scale and rotation are read for anything drawn, and not for an adjustment")
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

    @Test("a format duration that is not above 0 stops", arguments: ["0", "-1"])
    func refusesDurationNotAboveZero(duration: String) throws {
        // Given
        let text = try replacingFirst(#""duration": 3,"#, with: #""duration": \#(duration),"#, in: written(Self.documents[0]))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == "format.duration (format): a sequence's duration is above 0, found \(duration)")
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

    @Test(
        "a mask that is not a closed polyline through three points, has a negative feather or has an unknown mode stops",
        arguments: [
            (
                #"{ "polyline": { "points": [[0, 0], [10, 0], [5, 10]], "closed": false } }"#, "0", #""add""#,
                "clips[0].mask[0].value[0].geometry (mask): a path mask is a closed polyline through at least three points"
            ),
            (
                #"{ "polyline": { "points": [[0, 0], [10, 0]], "closed": true } }"#, "0", #""add""#,
                "clips[0].mask[0].value[0].geometry (mask): a path mask is a closed polyline through at least three points"
            ),
            (
                #"{ "rect": { "rect": [0, 0, 10, 10], "radius": 0 } }"#, "-1", #""add""#,
                "clips[0].mask[0].value[0].feather (mask): a feather is 0 or more, found -1"
            ),
            (
                #"{ "ellipse": { "rect": [0, 0, 10, 10] } }"#, "0", #""multiply""#,
                #"clips[0].mask[0].value[0].mode (mask): unknown value "multiply". Allowed: add, subtract, intersect"#
            )
        ]
    )
    func refusesMask(
        geometry: String,
        feather: String,
        mode: String,
        message: String
    ) throws {
        // Given
        let mask = #"""
            [ { "at": 0, "value": [ { "geometry": \#(geometry), "feather": \#(feather), "invert": false, "mode": \#(mode) } ], "ease": "linear" } ]
            """#
        let text = try replacing("mask", ofClip: 0, with: mask, in: written(Self.documents[4]))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("a mask list with no mask stops, since a clip without masks has null")
    func refusesEmptyMaskList() throws {
        // Given
        let text = try replacing(
            "mask",
            ofClip: 0,
            with: #"[ { "at": 0, "value": [], "ease": "linear" } ]"#,
            in: written(Self.documents[4])
        )

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == "clips[0].mask[0].value (clip): a mask list holds at least one mask, and a clip without one has null")
    }

    @Test(
        "a track matte that names no clip, a storyline clip or an adjustment, or a chain that comes back to itself, stops",
        arguments: [
            (
                1,
                #"{ "clip": "ghost", "mode": "alpha", "invert": false }"#,
                #"clips[1].trackMatte.clip (clip): no clip in the document has the id "ghost", and a track matte is a clip of the same document"#
            ),
            (
                1,
                #"{ "clip": "screen", "mode": "alpha", "invert": false }"#,
                #"clips[1].trackMatte.clip (clip): "screen" is a storyline clip, and a track matte is a connected or sequence media clip, title or shape"#
            ),
            (
                1,
                #"{ "clip": "grade", "mode": "luma", "invert": false }"#,
                #"clips[1].trackMatte.clip (clip): "grade" is an adjustment clip, and a track matte is a connected or sequence media clip, title or shape"#
            ),
            (
                0,
                #"{ "clip": "bar", "mode": "alpha", "invert": false }"#,
                #"clips[0].trackMatte.clip (clip): the track matte chain comes back to itself: "word" > "bar" > "word""#
            )
        ]
    )
    func refusesTrackMatte(
        clip: Int,
        matte: String,
        message: String
    ) throws {
        // Given
        let text = try replacing("trackMatte", ofClip: clip, with: matte, in: written(Self.documents[5]))

        // When
        let error = #expect(throws: ResolveError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("a track matte with a mode other than alpha or luma, or without invert, stops")
    func refusesTrackMatteMode() throws {
        // Given
        let unknown = try replacing(
            "trackMatte",
            ofClip: 1,
            with: #"{ "clip": "bar", "mode": "red", "invert": false }"#,
            in: written(Self.documents[5])
        )
        let missing = try replacing(
            "trackMatte",
            ofClip: 1,
            with: #"{ "clip": "bar", "mode": "luma" }"#,
            in: written(Self.documents[5])
        )

        // When
        let unknownError = #expect(throws: ModelError.self) { try sut.read(unknown) }
        let missingError = #expect(throws: ModelError.self) { try sut.read(missing) }

        // Then
        #expect(unknownError?.description == #"clips[1].trackMatte.mode (track matte): unknown value "red". Allowed: alpha, luma"#)
        #expect(missingError?.description.hasPrefix("clips[1].trackMatte (track matte): missing") == true)
    }

    @Test("a track that turns and grows reads back as it was written, each frame's motion with its turn")
    func readsTurningTrack() throws {
        // Given
        let tracker = TrackerTable(frameTimes: Fixture.tracker.frameTimes, drift: Point(x: 3, y: -2), growth: 0.1, turn: 30)
        let document = try resolved(Self.documents[2], tracker: tracker)
        let text = writer.write(document)

        // When
        let read = try sut.read(text)

        // Then
        #expect(read == document)
        let track = try #require(read.clips.first?.track?.track)
        let last = try #require(track.samples.last)
        #expect(abs(last.motion.rotation - 30 * (last.time - track.mediaTime)) < 1e-9)
        #expect(last.motion.rotation > 0)
    }

    @Test(
        "a track motion that is not a similarity and a target of three points stop, naming their place",
        arguments: [
            (
                "motion",
                "[1, 0, 0, 2, 0, 0]",
                "clips[0].track.frames[0].motion (track): a track's motion is a move, one scale above 0 and one rotation, written [a, b, -b, a, tx, ty], found [1, 0, 0, 2, 0, 0]"
            ),
            (
                "motion",
                "[0, 0, 0, 0, 5, 5]",
                "clips[0].track.frames[0].motion (track): a track's motion is a move, one scale above 0 and one rotation, written [a, b, -b, a, tx, ty], found [0, 0, 0, 0, 5, 5]"
            ),
            (
                "target",
                "[[0, 0], [10, 0], [10, 10]]",
                "clips[0].track.target (track): expected a list of 4 points, found a list of 3"
            )
        ]
    )
    func refusesTrackShape(
        key: String,
        value: String,
        message: String
    ) throws {
        // Given
        let text = try replacingInTrack(ofClip: 0, in: written(Self.documents[2])) { track in
            guard key == "motion" else { return track.setting(key, to: try Fixture.json(value)) }

            var frames = try #require(track["frames"]?.arrayValue)
            let frame = try #require(frames[0].objectValue)
            frames[0] = .object(frame.setting(key, to: try Fixture.json(value)))
            return track.setting("frames", to: .array(frames))
        }

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    @Test("a track reads back with the media it follows, its parent's for a shape and its own for a storyline clip and a media clip of video")
    func readsTrackedMedia() throws {
        // Given
        let document = try resolved(Self.trackedDocument)
        let text = writer.write(document)

        // When
        let read = try sut.read(text)

        // Then
        #expect(read == document)
    }

    @Test(
        "a track that pins other media than the one its clip follows stops, naming the track's media",
        arguments: [
            (
                "clips",
                0,
                "/abs/short.mp4",
                "clips[0].track.media (track): the clip follows its parent's media, so its track pins the media its parent shows"
            ),
            (
                "clips",
                1,
                "/abs/screen.mp4",
                "clips[1].track.media (track): the clip follows its own media, so its track pins the media the clip shows"
            ),
            (
                "storyline",
                0,
                "/abs/short.mp4",
                "storyline[0].track.media (track): the clip follows its own media, so its track pins the media the clip shows"
            )
        ]
    )
    func refusesTrackedMedia(
        list: String,
        index: Int,
        file: String,
        message: String
    ) throws {
        // Given
        // The screen and the shape follow the screen, and the media clip the short, so each is given the other's.
        let root = try #require(try JSONReader().read(written(Self.trackedDocument)).objectValue)
        let pinned = (root["clips"]?.arrayValue ?? []).compactMap { $0.objectValue?["track"]?.objectValue?["media"] }
        let media = try #require(pinned.first { $0.objectValue?["file"]?.stringValue == file })
        var entries = try #require(root[list]?.arrayValue)
        let entry = try #require(entries[index].objectValue)
        let track = try #require(entry["track"]?.objectValue)
        entries[index] = .object(entry.setting("track", to: .object(track.setting("media", to: media))))
        let text = JSONWriter().write(.object(root.setting(list, to: .array(entries))))

        // When
        let error = #expect(throws: ModelError.self) { try sut.read(text) }

        // Then
        #expect(error?.description == message)
    }

    // MARK: - Private
    private func resolved(
        _ document: String,
        tracker: TrackerTable = Fixture.tracker
    ) throws -> ResolvedSequence {
        let planner = DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: Self.presets,
            ocr: Fixture.ocr,
            tracker: tracker,
            shaper: Fixture.shaper,
            library: Fixture.library
        )

        return try ResolvedSequence(plan: planner.plan(Fixture.json(document)), hashes: FileHashTable())
    }

    private func written(_ document: String) throws -> String {
        writer.write(try resolved(document))
    }

    private func replacing(
        _ key: String,
        ofClip index: Int,
        with value: String,
        in text: String
    ) throws -> String {
        let root = try #require(try JSONReader().read(text).objectValue)
        var clips = try #require(root["clips"]?.arrayValue)
        let clip = try #require(clips[index].objectValue)
        clips[index] = .object(clip.setting(key, to: try Fixture.json(value)))

        return JSONWriter().write(.object(root.setting("clips", to: .array(clips))))
    }

    private func replacingInTrack(
        ofClip index: Int,
        in text: String,
        _ change: (JSONObject) throws -> JSONObject
    ) throws -> String {
        let root = try #require(try JSONReader().read(text).objectValue)
        var clips = try #require(root["clips"]?.arrayValue)
        let clip = try #require(clips[index].objectValue)
        let track = try #require(clip["track"]?.objectValue)
        clips[index] = .object(clip.setting("track", to: .object(try change(track))))

        return JSONWriter().write(.object(root.setting("clips", to: .array(clips))))
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

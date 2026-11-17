//
//  ResolvedSequenceWriterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("ResolvedSequenceWriter Tests")
struct ResolvedSequenceWriterTests {
    // MARK: - Property
    private let sut = ResolvedDocumentWriter()
    private let hashes = FileHashTable(["/abs/run.mp4": "9f2c41d07b3e"])

    // A transition with spans, a cover and a matte, and a filter with a LUT, so every file a preset opens is pinned.
    private let presets = PresetTable(
        transitions: [
            "reveal": TransitionPreset(
                description: "",
                seconds: 1,
                over: .incoming,
                incoming: Span(ease: .easeOut, keys: [SpanKey(t: 0, values: [.scale: 1.2, .opacity: 0]), SpanKey(t: 1, values: [:])]),
                outgoing: nil,
                cover: Cover(source: .media("/abs/leak.mov"), span: Span(ease: .linear, keys: [])),
                matte: Matte(media: "/abs/matte.png", softness: 0.1, isInverted: true, ease: .easeIn)
            )
        ],
        animations: Fixture.presets.animations,
        filters: ["film": FilterPreset(description: "", operations: [.lut(file: "/abs/film.cube", amount: 0.5)])]
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("the root is its kind, the version of this frames, then the sequence's members")
    func writesRoot() throws {
        // Given
        let document = #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2 } ] }"#

        // When
        let resolved = try write(document)

        // Then
        #expect(resolved.keys == ["kind", "resolved", "format", "storyline", "clips", "audio"])
        #expect(resolved["kind"] == .string("sequence"))
        #expect(resolved["resolved"] == .string(FramesVersion.current))
        #expect(resolved["format"]?.objectValue?.keys == ["size", "fps", "duration", "background", "content", "conform"])
        #expect(resolved["format"]?.objectValue?["duration"] == .number(3))
        #expect(resolved["format"]?.objectValue?["background"]?.stringValue?.count == 9)
    }

    @Test("a storyline entry keeps media time for in, out and speed, and sequence time for start and end")
    func writesStorylineTimes() throws {
        // Given
        let document = #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2 } ] }"#

        // When
        let entry = try #require(try write(document)["storyline"]?.arrayValue?.first?.objectValue)

        // Then
        #expect(entry["place"] == .string("storyline[0]"))
        #expect(entry["media"]?.objectValue?.keys == ["file", "sha256"])
        #expect(entry["media"]?.objectValue?["sha256"] == .string("9f2c41d07b3e"))
        #expect(entry["in"] == .number(2))
        #expect(entry["out"] == .number(8))
        #expect(entry["speed"] == .number(2))
        #expect(entry["start"] == .number(0))
        #expect(entry["end"] == .number(3))
        #expect(entry["transition"] == .null)
        #expect(entry["filter"] == .array([]))
    }

    @Test("a storyline crop is written conformed to the content rect, and no crop is the whole picture conformed")
    func writesConformedCrop() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [1080, 1920], "inset": [40, 40, 500, 40] },
              "storyline": [ { "media": "/abs/screen.mp4", "in": 0, "out": 1, "crop": [0, 0, 1206, 1206] },
                             { "media": "/abs/card.png", "duration": 1 } ] }
            """#
        let content = Rectangle(x: 40, y: 40, width: 1000, height: 1380)
        let conformer = CropConformer()
        let cropped = conformer.conformed(Rectangle(x: 0, y: 0, width: 1206, height: 1206), to: content, by: .fit)
        let whole = conformer.conformed(Rectangle(x: 0, y: 0, width: 1080, height: 1350), to: content, by: .fit)

        // When
        let storyline = try #require(try write(document)["storyline"]?.arrayValue)

        // Then
        #expect(storyline[0].objectValue?["crop"] == keyframes(at: 0, cropped))
        #expect(storyline[1].objectValue?["crop"] == keyframes(at: 1, whole))
    }

    @Test("an image sequence is pinned frame by frame, in order, with its frame times")
    func pinsImageSequence() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": { "imageSequence": "/abs/frames", "fps": 12 } } ] }
            """#

        // When
        let media = try #require(try write(document)["storyline"]?.arrayValue?.first?.objectValue?["media"]?.objectValue)

        // Then
        let frames = try #require(media["imageSequence"]?.arrayValue)
        #expect(media.keys == ["imageSequence", "frames"])
        #expect(frames.compactMap { $0.objectValue?["file"]?.stringValue } == Fixture.imageSequenceFiles)
        #expect(frames.compactMap { $0.objectValue?["sha256"]?.stringValue } == Fixture.imageSequenceFiles.map { "sha256-of-" + $0 })
        #expect(media["frames"]?.arrayValue?.count == 12)
        #expect(media["frames"]?.arrayValue?[1] == .number(1.0 / 12))
    }

    @Test("a title carries its runs with the font pinned, and glyphs as [id, x, y] in its box")
    func writesShapedTitle() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "title": "Hi", "style": "label", "placement": "top", "at": [0, 1] } ] }
            """#

        // When
        let title = try #require(try write(document)["clips"]?.arrayValue?.first?.objectValue?["title"]?.objectValue)

        // Then
        let run = try #require(title["runs"]?.arrayValue?.first?.objectValue)
        #expect(title.keys == ["size", "lines", "background", "stroke", "runs"])
        #expect(run.keys == ["file", "sha256", "face", "size", "color", "glyphs"])
        #expect(run["sha256"] == .string("sha256-of-" + (run["file"]?.stringValue ?? "")))
        #expect(run["glyphs"]?.arrayValue?.compactMap { $0.arrayValue?.first } == [.number(72), .number(105)])
        #expect(run["glyphs"]?.arrayValue?.allSatisfy { $0.arrayValue?.count == 3 } == true)
    }

    @Test("a clip keeps its place, id, visible window, lane, storyline and parenting, and its properties in sequence time")
    func writesClip() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 8, "connected": [
                { "id": "mark", "shape": "box", "area": [0, 0, 100, 100], "at": [3, 5], "lane": -1,
                  "keyframes": [ { "at": 3, "opacity": 0, "ease": [0.3, 0, 0.2, 1] }, { "at": 4, "opacity": 1 } ] } ] } ] }
            """#

        // When
        let clip = try #require(try write(document)["clips"]?.arrayValue?.first?.objectValue)

        // Then
        #expect(clip["place"] == .string("storyline[0].connected[0]#mark"))
        #expect(clip["id"] == .string("mark"))
        #expect(clip["shape"] == .string("box"))
        #expect(clip["color"] == .string(MergedTheme.base.shapeColor(of: .box).hex))
        #expect(clip["start"] == .number(1))
        #expect(clip["end"] == .number(3))
        #expect(clip["lane"] == .number(-1))
        #expect(clip["storyline"] == .number(0))
        #expect(clip["parented"] == .bool(true))
        #expect(clip["area"] == keyframes(at: 1, Rectangle(x: 0, y: 0, width: 100, height: 100)))
        #expect(clip["opacity"] == .array([
            .object(JSONObject(members: [
                JSONMember(key: "at", value: .number(1)),
                JSONMember(key: "value", value: .number(0)),
                JSONMember(key: "ease", value: .array([.number(0.3), .number(0), .number(0.2), .number(1)]))
            ])),
            .object(JSONObject(members: [
                JSONMember(key: "at", value: .number(2)),
                JSONMember(key: "value", value: .number(1)),
                JSONMember(key: "ease", value: .string("linear"))
            ]))
        ]))
        #expect(clip["scale"] == nil)
        #expect(clip["blend"] == .string("normal"))
    }

    @Test("a media clip carries its box, its crop conformed to it, its corners, border and shadow, with theme lengths scaled")
    func writesMediaAppearance() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "media": "/abs/card.png", "at": [0, 3], "width": 300, "height": 300, "conform": "fill", "position": [540, 960],
                           "radius": 12, "border": true, "shadow": true } ] }
            """#

        // When
        let clips = try #require(try write(document)["clips"]?.arrayValue)

        // Then
        let clip = try #require(clips.first?.objectValue)
        #expect(clip["size"] == .array([.number(300), .number(300)]))
        #expect(clip["position"] == .array([.object(JSONObject(members: [
            JSONMember(key: "at", value: .number(0)),
            JSONMember(key: "value", value: .array([.number(390), .number(810)])),
            JSONMember(key: "ease", value: .string("linear"))
        ]))]))
        #expect(clip["anchor"] == .array([.number(150), .number(150)]))
        #expect(clip["crop"] == keyframes(at: 0, Rectangle(x: 0, y: 135, width: 1080, height: 1080)))
        #expect(clip["conform"] == .string("fill"))
        #expect(clip["radius"] == .number(12))
        #expect(clip["border"] == .object(JSONObject(members: [
            JSONMember(key: "width", value: .number(2.6865671641791047)),
            JSONMember(key: "color", value: .string("#D9D9D9FF"))
        ])))
        #expect(clip["shadow"] == .object(JSONObject(members: [
            JSONMember(key: "radius", value: .number(21.492537313432837)),
            JSONMember(key: "offset", value: .array([.number(0), .number(7.164179104477612)])),
            JSONMember(key: "color", value: .string("#00000059"))
        ])))
    }

    @Test("a solid storyline clip carries its colour as #RRGGBBAA, a theme colour by its value")
    func writesSolidColor() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [1080, 1920] }, "storyline": [ { "solid": "accent", "duration": 1 } ] }
            """#

        // When
        let storyline = try #require(try write(document)["storyline"]?.arrayValue)

        // Then
        #expect(storyline.first?.objectValue?["solid"] == .string("#ED2929FF"))
        #expect(storyline.first?.objectValue?["media"] == .null)
    }

    @Test("a transition carries its spans inline and its cover and matte media pinned with their frames and length, and a LUT is pinned")
    func writesTransitionAndLUT() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": "film" },
                                                 { "media": "/abs/run.mp4", "in": 0, "out": 3, "transition": "reveal" } ] }
            """#

        // When
        let storyline = try #require(try write(document, presets: presets)["storyline"]?.arrayValue)

        // Then
        let transition = try #require(storyline[1].objectValue?["transition"]?.objectValue)
        let incoming = try #require(transition["incoming"]?.objectValue)
        #expect(transition.keys == ["start", "end", "over", "incoming", "outgoing", "cover", "matte"])
        #expect(transition["start"] == .number(2.5))
        #expect(transition["end"] == .number(3.5))
        #expect(incoming["ease"] == .string("ease-out"))
        #expect(incoming["keys"]?.arrayValue?.first?.objectValue?.keys == ["t", "opacity", "scale"])
        #expect(transition["cover"]?.objectValue?.keys == ["file", "sha256", "frames", "duration", "ease", "revealFrom", "keys"])
        #expect(transition["cover"]?.objectValue?["sha256"] == .string("sha256-of-/abs/leak.mov"))
        #expect(transition["cover"]?.objectValue?["frames"] == .array([0, 0.5, 1, 1.5].map(JSONValue.number)))
        #expect(transition["cover"]?.objectValue?["duration"] == .number(2))
        #expect(transition["matte"]?.objectValue?.keys == ["file", "sha256", "duration", "softness", "invert", "ease"])
        #expect(transition["matte"]?.objectValue?["duration"] == .number(0))
        #expect(storyline[0].objectValue?["filter"]?.arrayValue?.first?.objectValue?.keys == ["op", "file", "sha256", "amount"])
    }

    @Test("a shape's label carries its side, the time its side was chosen at, its shaped text and its own animation")
    func writesLabel() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "shape": "box", "area": [100, 100, 100, 100], "at": [1, 3], "label": "a", "labelAnimation": "frames/fade" } ] }
            """#

        // When
        let label = try #require(try write(document)["clips"]?.arrayValue?.first?.objectValue?["label"]?.objectValue)

        // Then
        let animation = try #require(label["animation"]?.objectValue)
        #expect(label.keys == ["side", "at", "text", "animation"])
        #expect(label["at"] == .number(1))
        #expect(label["text"]?.objectValue?.keys == ["size", "lines", "background", "stroke", "runs"])
        #expect(animation["entrance"]?.objectValue?["seconds"] == .number(0.25))
        #expect(animation["loop"] == .null)
        #expect(animation["exit"]?.objectValue?["seconds"] == .number(0.25))
    }

    @Test("a clip whose tracked area is a band writes band true, and one tracking any other area false")
    func writesBand() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "in": 1, "out": 3, "connected": [
                { "shape": "box", "area": "Total", "track": "Total" },
                { "shape": "fill", "area": { "band": "Total" }, "track": true } ] } ] }
            """#

        // When
        let clips = try #require(try write(document)["clips"]?.arrayValue?.compactMap(\.objectValue))

        // Then
        #expect(clips[0]["track"]?.objectValue?.keys == ["target", "time", "band", "frames"])
        #expect(clips[0]["track"]?.objectValue?["band"] == .bool(false))
        #expect(clips[1]["track"]?.objectValue?["band"] == .bool(true))
    }

    @Test("a media clip plays in at its window's start, written as origin, even where tracking narrowed its start")
    func writesOriginOfNarrowedClip() throws {
        // Given
        // The second clip is drawn from 1.75 by its transition, but "Total" is followed only from media second 1,
        // which it shows at its edit point 2.
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 2 },
              { "media": "/abs/screen.mp4", "in": 1, "out": 3, "transition": "frames/flash", "connected": [
                { "media": "/abs/short.mp4", "parent": true, "position": [0, 0], "track": "Total" } ] } ] }
            """#
        let tracker = TrackerTable(frameTimes: ["/abs/screen.mp4": Fixture.screenFrameTimes], followed: ["/abs/screen.mp4": 1...4])

        // When
        let clip = try #require(try write(document, tracker: tracker)["clips"]?.arrayValue?.first?.objectValue)

        // Then
        #expect(clip["start"] == .number(2))
        #expect(clip["in"] == .number(0))
        #expect(clip["origin"] == .number(1.75))
    }

    @Test("a compound clip carries its nested resolved sequence in place of a file")
    func writesCompoundClip() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": {
                "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 2 } ] } } ] }
            """#

        // When
        let resolved = try write(document)

        // Then
        let nested = try #require(resolved["storyline"]?.arrayValue?.first?.objectValue?["media"]?.objectValue)
        #expect(nested.keys == ["kind", "format", "storyline", "clips", "audio"])
        #expect(nested["storyline"]?.arrayValue?.first?.objectValue?["media"]?.objectValue?["file"] == .string("/abs/run.mp4"))
        #expect(resolved["audio"]?.arrayValue?.first?.objectValue?["media"] == .null)
        #expect(resolved["audio"]?.arrayValue?.first?.objectValue?["nested"]?.arrayValue?.count == 1)
    }

    @Test("audio is every source of sound, with its volume in sequence time")
    func writesAudio() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3 } ],
              "clips": [ { "media": "/abs/bgm.m4a", "at": 1, "loop": true,
                           "keyframes": [ { "at": 0, "volume": 0.3 }, { "at": 1, "volume": 0 } ] } ] }
            """#

        // When
        let resolved = try write(document)

        // Then
        let audio = try #require(resolved["audio"]?.arrayValue)
        let music = try #require(audio.last?.objectValue)
        #expect(resolved["clips"] == .array([]))
        #expect(audio.count == 2)
        #expect(music["place"] == .string("clips[0]"))
        #expect(music["loop"] == .bool(true))
        #expect(music["start"] == .number(1))
        #expect(music["volume"]?.arrayValue?.compactMap { $0.objectValue?["at"] } == [.number(0), .number(1)])
    }

    @Test("a shape carries how it is drawn, with theme lengths scaled: a box its stroke and corners, an arrow its side and lengths")
    func writesShapeDrawing() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "format": { "size": [2412, 5244] }, "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [
                { "shape": "box", "area": [0, 0, 100, 100], "at": [0, 1] },
                { "shape": "arrow", "side": "left", "area": [500, 500, 100, 100], "at": [0, 1], "color": "#FF0000" },
                { "shape": "dim", "area": [0, 0, 100, 100], "at": [0, 1] } ] }
            """#
        let theme = MergedTheme.base
        let scale = theme.lengthScale(at: 2412)

        // When
        let clips = try #require(try write(document)["clips"]?.arrayValue?.compactMap(\.objectValue))

        // Then
        #expect(clips[0]["width"] == .number(theme.boxWidth * scale))
        #expect(clips[0]["radius"] == .number(theme.boxRadius * scale))
        #expect(clips[0]["color"] == .string(theme.shapeColor(of: .box).hex))
        #expect(clips[1]["side"] == .string("left"))
        #expect(clips[1]["length"] == .number(theme.arrowLength * scale))
        #expect(clips[1]["width"] == .number(theme.arrowWidth * scale))
        #expect(clips[1]["head"] == .number(theme.arrowHead * scale))
        #expect(clips[1]["color"] == .string("#FF0000FF"))
        #expect(clips[2]["color"] == .string(theme.shapeColor(of: .dim).hex))
        #expect(clips[2]["width"] == nil)
    }

    // MARK: - Private
    private func write(
        _ document: String,
        presets: PresetTable = Fixture.presets,
        tracker: TrackerTable = Fixture.tracker
    ) throws -> JSONObject {
        let planner = DocumentPlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: presets,
            ocr: Fixture.ocr,
            tracker: tracker,
            shaper: Fixture.shaper,
            library: Fixture.library
        )
        let text = sut.write(try ResolvedDocument(plan: planner.plan(Fixture.json(document)), hashes: hashes))

        return try #require(try JSONReader().read(text).objectValue)
    }

    private func keyframes(
        at instant: Double,
        _ rectangle: Rectangle
    ) -> JSONValue {
        .array([.object(JSONObject(members: [
            JSONMember(key: "at", value: .number(instant)),
            JSONMember(key: "value", value: .array([rectangle.x, rectangle.y, rectangle.width, rectangle.height].map(JSONValue.number))),
            JSONMember(key: "ease", value: .string("linear"))
        ]))])
    }
}

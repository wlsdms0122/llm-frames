//
//  SequenceReaderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("SequenceReader Tests")
struct SequenceReaderTests {
    // MARK: - Property
    private let sut = SequenceReader()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a checked sequence reads into model types with every clip's place")
    func readsSequence() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "format": { "fps": 25 }, "theme": { "defaults": { "transition": "frames/push-up" } },
              "storyline": [
                { "id": "run", "kind": "media", "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2,
                  "keyframes": [ { "at": 2, "crop": { "scale": 1 }, "ease": "ease-in-out" } ],
                  "connected": [ { "at": [2, 8], "kind": "title", "text": "a", "style": "subtitle" },
                                 { "kind": "rect", "stroke": { "width": 8 }, "parent": "run", "keyframes": [ { "at": 1.2, "area": [60, 400, 600, 80] } ] } ] },
                { "kind": "media", "media": "/abs/card.png", "duration": 2.5, "transition": { "preset": "frames/wipe-right", "seconds": 0.5 } },
                { "kind": "solid", "color": "#000000", "duration": 1, "transition": "cut" }
              ],
              "clips": [
                { "at": 1.0, "kind": "media", "media": "/abs/ding.wav", "in": 0, "out": 1.5 },
                { "kind": "media", "media": { "imageSequence": "/abs/frames", "fps": 30 }, "loop": true, "lane": -1, "parent": "run", "placement": "top" },
                { "kind": "adjustment", "adjust": "frames/vivid", "animation": { "entrance": "frames/pop", "exit": "none" } },
                { "kind": "title", "text": [ { "text": "Ana\n" }, { "text": "Director", "style": "role" } ], "style": "name" }
              ] }
            """##)

        // When
        let sequence = sut.sequence(from: document)

        // Then
        #expect(sequence.format.fps == 25)
        #expect(sequence.theme == .object(try Fixture.json(#"{ "defaults": { "transition": "frames/push-up" } }"#)))
        #expect(sequence.storyline[0].place.description == "storyline[0]#run")
        #expect(sequence.storyline[0].media == ClipMedia(source: .file("/abs/run.mp4"), in: 2, out: 8, speed: 2))
        #expect(sequence.storyline[0].keyframes == [KeyframeInstant(index: 0, at: 2, leaves: [Place.root.appending(key: "crop")])])
        #expect(sequence.storyline[0].connected[0].at == .range(start: 2, end: 8))
        #expect(sequence.storyline[0].connected[0].content == .title(ClipTitle(
            runs: [TitleRun(text: "a", style: nil)],
            style: "subtitle",
            character: nil,
            paragraph: nil
        )))
        #expect(sequence.storyline[0].connected[1].place.description == "storyline[0]#run.connected[1]")
        #expect(sequence.storyline[0].connected[1].parent == "run")
        #expect(sequence.storyline[1].transition == .object(try Fixture.object(#"{ "preset": "frames/wipe-right", "seconds": 0.5 }"#)))
        #expect(sequence.storyline[1].duration == 2.5)
        #expect(sequence.storyline[2].media == nil)
        #expect(sequence.storyline[2].transition == .string("cut"))
        #expect(sequence.clips[0].at == .start(1))
        #expect(sequence.clips[0].clipPlace == .sequence)
        #expect(sequence.clips[1].content == .media(ClipMedia(source: .imageSequence(directory: "/abs/frames", fps: 30), loop: true)))
        #expect(sequence.clips[1].lane == -1)
        #expect(sequence.clips[1].parent == "run" && sequence.clips[1].placement == "top")
        #expect(sequence.clips[2].content == .adjust)
        #expect(sequence.clips[2].animation == .object(try Fixture.object(#"{ "entrance": "frames/pop", "exit": "none" }"#)))
        #expect(sequence.clips[3].content == .title(ClipTitle(
            runs: [TitleRun(text: "Ana\n", style: nil), TitleRun(text: "Director", style: "role")],
            style: "name",
            character: nil,
            paragraph: nil
        )))
    }

    @Test("a page of a PDF reads as its file and its page number")
    func readsPage() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": { "file": "/abs/deck.pdf", "page": 3 }, "colorSpace": "rec709" } ] }"#)

        // When
        let sequence = sut.sequence(from: document)

        // Then
        #expect(sequence.storyline[0].media == ClipMedia(source: .page(file: "/abs/deck.pdf", page: 3), colorSpace: .rec709))
    }

    @Test("a nested sequence reads as a compound clip whose places continue the place of the clip that holds it")
    func readsCompoundClip() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": { "kind": "sequence", "theme": "shorts/shorts", "storyline": [ { "kind": "solid", "color": "#000000", "duration": 1 } ] } } ] }
            """##)

        // When
        let sequence = sut.sequence(from: document)

        // Then
        guard case let .compound(nested)? = sequence.storyline[0].media?.source else {
            Issue.record("expected a compound clip")
            return
        }
        #expect(nested.place.description == "storyline[0].media")
        #expect(nested.theme == .named("shorts/shorts"))
        #expect(nested.storyline[0].place.description == "storyline[0].media.storyline[0]")
    }

    @Test("a template instance keeps its arguments, and media at an argument place keeps the theme it was given with")
    func readsInstanceAndArguments() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [
              { "kind": "media", "media": { "template": "shorts/leak", "args": { "clip": "/abs/run.mp4" } } },
              { "kind": "media", "media": "/abs/run.mp4" }
            ] }
            """#)
        let theme = try ThemeMerger().merge([ThemeLayer(value: Fixture.json(#"{ "defaults": { "transition": "frames/flash" } }"#), place: .root)])
        let place = Place(components: [.key("storyline"), .index(1, id: nil), .key("media")])
        let sut = SequenceReader(argumentThemes: ArgumentThemeTable(themes: [place: theme]))

        // When
        let sequence = sut.sequence(from: document)

        // Then
        let arguments = try Fixture.object(#"{ "clip": "/abs/run.mp4" }"#)
        #expect(sequence.storyline[0].media?.source == .template(name: "shorts/leak", arguments: arguments, passedOnThemes: .empty))
        #expect(sequence.storyline[1].media?.source == .argument(.file("/abs/run.mp4"), theme: theme))
    }

    @Test("the geometry keys read as written: the format's size and conform, areas and track data")
    func readsGeometryKeys() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "format": { "size": [1080, 1920], "conform": "fill" },
              "storyline": [ { "kind": "media", "media": "/abs/screen.mp4", "track": { "time": 1, "frames": [] }, "crop": { "scale": 2 }, "connected": [
                { "kind": "ellipse", "area": { "clip": "t", "padding": 6 }, "fill": "accent",
                  "track": { "time": 0.5, "frames": [ { "time": 0.5, "quad": [[10, 20], [40, 20], [40, 60], [10, 60]] } ] } },
                { "id": "t", "kind": "title", "text": "t", "style": "title", "width": 300, "parent": "screen",
                  "position": { "area": [1, 2, 3, 4], "point": "top-left" } } ] } ] }
            """#)

        // When
        let sequence = sut.sequence(from: document)

        // Then
        let ellipse = sequence.storyline[0].connected[0]
        let title = sequence.storyline[0].connected[1]
        #expect(sequence.format.size == .fixed(Size(width: 1080, height: 1920)))
        #expect(sequence.format.conform == .fill)
        #expect(sequence.storyline[0].track == TrackData(time: 1, frames: []))
        #expect(sequence.storyline[0].crop == .value(.scale(2)))
        #expect(ellipse.area == .value(.clip("t", padding: 6)))
        #expect(ellipse.content == .shape(ClipShape(kind: .ellipse, fill: LookProperty(written: .string("accent")))))
        #expect(ellipse.track == TrackData(time: 0.5, frames: [TrackDataFrame(time: 0.5, quad: Quad(Rectangle(x: 10, y: 20, width: 30, height: 40)))]))
        #expect(title.width == 300)
        #expect(title.position == .value(.area(.rectangle(Rectangle(x: 1, y: 2, width: 3, height: 4)), point: "top-left")))
    }

    @Test("a shape's own keys read as written, each nil where it is not, and its scale and rotation are kept")
    func readsShapeKeys() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "clips": [
              { "kind": "rect", "style": "outline", "width": 100, "height": 50, "radius": 8, "outset": 4, "fill": false,
                "stroke": { "width": 2, "join": "bevel", "end": "frames/arrow" }, "shadow": true, "scale": 2, "rotation": 30 },
              { "kind": "path", "points": [[0, 0], { "vertex": { "area": [0, 0, 10, 10], "point": "right" } }], "closed": true,
                "fill": "#FF0000", "stroke": false, "shadow": { "radius": 4, "color": "accent" },
                "keyframes": [ { "at": 1, "trim": [0, 0.5] }, { "at": 2, "trim": [0, 1], "ease": "ease-in" } ] },
              { "kind": "ellipse", "area": [0, 0, 10, 10], "shadow": false } ] }
            """##)

        // When
        let sequence = sut.sequence(from: document)

        // Then
        #expect(sequence.clips[0].content == .shape(ClipShape(
            kind: .rect,
            style: "outline",
            width: .value(100),
            height: .value(50),
            radius: LookProperty(written: .number(8)),
            outset: LookProperty(written: .number(4)),
            fill: LookProperty(written: .bool(false)),
            stroke: LookProperty(written: try Fixture.json(#"{ "width": 2, "join": "bevel", "end": "frames/arrow" }"#)),
            shadow: LookProperty(written: .bool(true))
        )))
        #expect(sequence.clips[0].scale == .value(Scale(2)))
        #expect(sequence.clips[0].rotation == .value(30))
        #expect(sequence.clips[1].content == .shape(ClipShape(
            kind: .path,
            points: PathProperty(
                written: [try Fixture.json("[0, 0]"), try Fixture.json(#"{ "area": [0, 0, 10, 10], "point": "right" }"#)],
                keyframes: []
            ),
            isClosed: true,
            fill: LookProperty(written: .string("#FF0000")),
            stroke: LookProperty(written: .bool(false)),
            trim: .keyframes([
                PropertyKeyframe(index: 0, at: 1, value: Trim(start: 0, end: 0.5), ease: .linear),
                PropertyKeyframe(index: 1, at: 2, value: .whole, ease: .easeIn)
            ]),
            shadow: LookProperty(written: try Fixture.json(#"{ "radius": 4, "color": "accent" }"#))
        )))
        #expect(sequence.clips[2].content == .shape(ClipShape(kind: .ellipse, shadow: LookProperty(written: .bool(false)))))
    }

    @Test(
        "a content fit size reads its margin in each form, in the order CSS writes them, and 0 without one",
        arguments: [
            (#"{ "fit": "content" }"#, Margin.zero),
            (#"{ "fit": "content", "margin": 8 }"#, Margin(top: 8, right: 8, bottom: 8, left: 8)),
            (#"{ "fit": "content", "margin": [8, 16] }"#, Margin(top: 8, right: 16, bottom: 8, left: 16)),
            (#"{ "fit": "content", "margin": [1, 2, 3, 4] }"#, Margin(top: 1, right: 2, bottom: 3, left: 4))
        ]
    )
    func readsContentFitSize(
        size: String,
        margin: Margin
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "format": { "size": \#(size) }, "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }
            """#)

        // When
        let sequence = sut.sequence(from: document)

        // Then
        #expect(sequence.format.size == .content(margin: margin))
    }
}

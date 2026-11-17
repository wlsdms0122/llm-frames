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
                { "id": "run", "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2,
                  "keyframes": [ { "at": 2, "crop": { "scale": 1 }, "ease": "ease-in-out" } ],
                  "connected": [ { "at": [2, 8], "title": "a", "style": "subtitle" },
                                 { "shape": "box", "keyframes": [ { "at": 1.2, "area": "First line" } ] } ] },
                { "media": { "kind": "image", "source": "/abs/card.png" }, "duration": 2.5, "transition": { "preset": "frames/wipe-right", "seconds": 0.5 } },
                { "solid": "#000000", "duration": 1, "transition": "cut" }
              ],
              "clips": [
                { "at": 1.0, "media": "/abs/ding.wav", "in": 0, "out": 1.5 },
                { "media": { "imageSequence": "/abs/frames", "fps": 30 }, "loop": true, "lane": -1, "parent": true, "placement": "top" },
                { "adjust": "frames/vivid", "animation": { "entrance": "frames/pop", "exit": "none" } }
              ] }
            """##)

        // When
        let sequence = sut.sequence(from: document)

        // Then
        #expect(sequence.format.fps == 25)
        #expect(sequence.theme == .object(try Fixture.json(#"{ "defaults": { "transition": "frames/push-up" } }"#)))
        #expect(sequence.storyline[0].place.description == "storyline[0]#run")
        #expect(sequence.storyline[0].media == ClipMedia(source: .file("/abs/run.mp4"), in: 2, out: 8, speed: 2))
        #expect(sequence.storyline[0].keyframes == [KeyframeInstant(index: 0, at: 2, properties: ["crop"])])
        #expect(sequence.storyline[0].connected[0].at == .range(start: 2, end: 8))
        #expect(sequence.storyline[0].connected[0].content == .title(text: "a", style: "subtitle"))
        #expect(sequence.storyline[0].connected[1].place.description == "storyline[0]#run.connected[1]")
        #expect(sequence.storyline[0].connected[1].hasArea)
        #expect(sequence.storyline[1].transition == .timed(preset: "frames/wipe-right", seconds: 0.5))
        #expect(sequence.storyline[1].duration == 2.5)
        #expect(sequence.storyline[2].media == nil)
        #expect(sequence.storyline[2].transition == .cut)
        #expect(sequence.clips[0].at == .start(1))
        #expect(sequence.clips[0].clipPlace == .sequence)
        #expect(sequence.clips[1].content == .media(ClipMedia(source: .imageSequence(directory: "/abs/frames", fps: 30), loop: true)))
        #expect(sequence.clips[1].lane == -1)
        #expect(sequence.clips[1].hasParent && sequence.clips[1].hasPlacement)
        #expect(sequence.clips[2].content == .adjust)
        #expect(sequence.clips[2].animation == .split(entrance: "frames/pop", exit: "none"))
    }

    @Test("a nested sequence reads as a compound clip whose places continue the place of the clip that holds it")
    func readsCompoundClip() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [ { "media": { "kind": "sequence", "theme": "shorts/shorts", "storyline": [ { "solid": "#000000", "duration": 1 } ] } } ] }
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
              { "media": { "template": "shorts/leak", "args": { "clip": "/abs/run.mp4" } } },
              { "media": "/abs/run.mp4" }
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

    @Test("the geometry keys read as written: the format's size, inset and conform, areas, labels and track targets")
    func readsGeometryKeys() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "format": { "size": [1080, 1920], "inset": [10, 20, 30, 40], "conform": "fill" },
              "storyline": [ { "media": "/abs/screen.mp4", "track": true, "crop": { "scale": 2 }, "connected": [
                { "shape": "arrow", "area": { "band": { "from": "a", "to": "b", "toNth": 1 } }, "side": "left",
                  "label": "here", "track": { "text": "c", "nth": 2 } },
                { "title": "t", "style": "label", "width": 300, "parent": true,
                  "position": { "area": [1, 2, 3, 4], "point": "top-left" } } ] } ] }
            """#)

        // When
        let sequence = sut.sequence(from: document)

        // Then
        let arrow = sequence.storyline[0].connected[0]
        let title = sequence.storyline[0].connected[1]
        #expect(sequence.format.size == Size(width: 1080, height: 1920))
        #expect(sequence.format.inset == Inset(top: 10, right: 20, bottom: 30, left: 40))
        #expect(sequence.format.conform == .fill)
        #expect(sequence.storyline[0].track == .own)
        #expect(sequence.storyline[0].crop == .value(.scale(2)))
        #expect(arrow.area == .value(.band(.range(from: "a", fromNth: nil, to: "b", toNth: 1))))
        #expect(arrow.content == .shape(.arrow(.left)))
        #expect(arrow.label == "here")
        #expect(arrow.track == .area(.text("c", nth: 2)))
        #expect(title.width == 300)
        #expect(title.position == .value(.area(.rectangle(Rectangle(x: 1, y: 2, width: 3, height: 4)), point: "top-left")))
    }
}

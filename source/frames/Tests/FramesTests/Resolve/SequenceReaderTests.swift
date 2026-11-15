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
            { "kind": "sequence", "format": { "fps": 25 }, "theme": { "defaults": { "transition": "push-up" } },
              "storyline": [
                { "id": "run", "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2,
                  "keyframes": [ { "at": 2, "crop": { "scale": 1 }, "ease": "ease-in-out" } ],
                  "connected": [ { "at": [2, 8], "title": "a", "style": "subtitle" },
                                 { "shape": "box", "keyframes": [ { "at": 1.2, "area": "First line" } ] } ] },
                { "media": { "kind": "image", "source": "/abs/card.png" }, "duration": 2.5, "transition": { "preset": "wipe-right", "seconds": 0.5 } },
                { "solid": "#000000", "duration": 1, "transition": "cut" }
              ],
              "clips": [
                { "at": 1.0, "media": "/abs/ding.wav", "in": 0, "out": 1.5 },
                { "media": { "imageSequence": "/abs/frames", "fps": 30 }, "loop": true, "lane": -1, "parent": true, "placement": "top" },
                { "adjust": "vivid", "animation": { "entrance": "pop", "exit": "none" } }
              ] }
            """##)

        // When
        let sequence = sut.sequence(from: document)

        // Then
        #expect(sequence.format.fps == 25)
        #expect(sequence.theme == .object(try Fixture.json(#"{ "defaults": { "transition": "push-up" } }"#)))
        #expect(sequence.storyline[0].place.description == "storyline[0]#run")
        #expect(sequence.storyline[0].media == ClipMedia(source: .file("/abs/run.mp4"), in: 2, out: 8, speed: 2))
        #expect(sequence.storyline[0].keyframes == [KeyframeInstant(index: 0, at: 2, properties: ["crop"])])
        #expect(sequence.storyline[0].connected[0].at == .range(start: 2, end: 8))
        #expect(sequence.storyline[0].connected[0].content == .title(style: "subtitle"))
        #expect(sequence.storyline[0].connected[1].place.description == "storyline[0]#run.connected[1]")
        #expect(sequence.storyline[0].connected[1].hasArea)
        #expect(sequence.storyline[1].transition == .timed(preset: "wipe-right", seconds: 0.5))
        #expect(sequence.storyline[1].duration == 2.5)
        #expect(sequence.storyline[2].media == nil)
        #expect(sequence.storyline[2].transition == .cut)
        #expect(sequence.clips[0].at == .start(1))
        #expect(sequence.clips[0].clipPlace == .sequence)
        #expect(sequence.clips[1].content == .media(ClipMedia(source: .imageSequence(directory: "/abs/frames", fps: 30), loop: true)))
        #expect(sequence.clips[1].lane == -1)
        #expect(sequence.clips[1].hasParent && sequence.clips[1].hasPlacement)
        #expect(sequence.clips[2].content == .adjust)
        #expect(sequence.clips[2].animation == .split(entrance: "pop", exit: "none"))
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
}

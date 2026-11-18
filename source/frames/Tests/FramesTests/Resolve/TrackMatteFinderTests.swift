//
//  TrackMatteFinderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

@Suite("TrackMatteFinder Tests")
struct TrackMatteFinderTests {
    // MARK: - Property
    private let sut = Fixture.planner

    // MARK: - Initializer
    // MARK: - Test
    @Test("a track matte is planned as written, on a storyline clip and on connected and sequence clips")
    func plansTrackMatte() throws {
        // Given
        let document = #"""
            { "kind": "sequence",
              "storyline": [ { "media": "/abs/screen.mp4", "trackMatte": { "clip": "word", "mode": "alpha" }, "connected": [
                { "id": "word", "title": "Hi", "style": "title", "at": [0, 1] },
                { "media": "/abs/card.png", "at": [0, 1], "trackMatte": { "clip": "bar", "mode": "luma", "invert": true } } ] } ],
              "clips": [ { "id": "bar", "shape": "rect", "fill": "#FFFFFF", "area": [0, 0, 10, 10], "at": [0, 1] } ] }
            """#

        // When
        let plan = try sut.plan(document: Fixture.json(document))

        // Then
        #expect(plan.storyline[0].trackMatte == TrackMatte(clip: "word", mode: .alpha, isInverted: false))
        #expect(plan.clips.map(\.trackMatte) == [nil, TrackMatte(clip: "bar", mode: .luma, isInverted: true), nil])
    }

    @Test("a clip used as a matte by two clips and a matte with a track matte of its own are fine")
    func acceptsSharedMatteAndChain() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [
              { "media": "/abs/card.png", "at": [0, 1], "trackMatte": { "clip": "word", "mode": "alpha" } },
              { "media": "/abs/card.png", "at": [0, 1], "trackMatte": { "clip": "word", "mode": "luma" } },
              { "id": "word", "title": "Hi", "style": "title", "at": [0, 1], "trackMatte": { "clip": "bar", "mode": "alpha" } },
              { "id": "bar", "shape": "rect", "fill": "#FFFFFF", "area": [0, 0, 10, 10], "at": [0, 1] } ] }
            """#

        // When
        let plan = try sut.plan(document: Fixture.json(document))

        // Then
        #expect(plan.clips.map { $0.trackMatte?.clip } == ["word", "word", "bar", nil])
    }

    @Test(
        "a track matte that names no clip, a storyline, adjustment or audio clip, or a chain that comes back to itself stops",
        arguments: [
            (
                #"{ "media": "/abs/card.png", "at": [0, 1], "trackMatte": { "clip": "missing", "mode": "alpha" } }"#,
                #"clips[0].trackMatte.clip (image): no clip in the document has the id "missing", and a track matte is a clip of the same document"#
            ),
            (
                #"{ "media": "/abs/card.png", "at": [0, 1], "trackMatte": { "clip": "screen", "mode": "alpha" } }"#,
                #"clips[0].trackMatte.clip (image): "screen" is a storyline clip, and a track matte is a connected or sequence media clip, title or shape"#
            ),
            (
                #"""
                { "id": "grade", "adjust": "mine/grade", "at": [0, 1] },
                { "media": "/abs/card.png", "at": [0, 1], "trackMatte": { "clip": "grade", "mode": "luma" } }
                """#,
                #"clips[1].trackMatte.clip (image): "grade" is an adjustment clip, and a track matte is a connected or sequence media clip, title or shape"#
            ),
            (
                #"""
                { "id": "sound", "media": "/abs/bgm.m4a", "at": [0, 1] },
                { "media": "/abs/card.png", "at": [0, 1], "trackMatte": { "clip": "sound", "mode": "alpha" } }
                """#,
                #"clips[1].trackMatte.clip (image): "sound" is an audio clip, and a track matte is a connected or sequence media clip, title or shape"#
            ),
            (
                #"{ "id": "self", "media": "/abs/card.png", "at": [0, 1], "trackMatte": { "clip": "self", "mode": "alpha" } }"#,
                #"clips[0]#self.trackMatte.clip (image): the track matte chain comes back to itself: "self" > "self""#
            ),
            (
                #"""
                { "id": "a", "media": "/abs/card.png", "at": [0, 1], "trackMatte": { "clip": "c", "mode": "alpha" } },
                { "id": "b", "title": "Hi", "style": "title", "at": [0, 1], "trackMatte": { "clip": "a", "mode": "luma" } },
                { "id": "c", "shape": "rect", "fill": "#FFFFFF", "area": [0, 0, 10, 10], "at": [0, 1], "trackMatte": { "clip": "b", "mode": "alpha" } }
                """#,
                #"clips[0]#a.trackMatte.clip (image): the track matte chain comes back to itself: "a" > "c" > "b" > "a""#
            )
        ]
    )
    func refusesTrackMatte(
        clips: String,
        message: String
    ) throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4" } ], "clips": [ \#(clips) ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: Fixture.json(document)) }
        #expect(error?.description == message)
    }

    @Test(
        "a track matte across a compound clip's edge names no clip, from outside or from inside",
        arguments: [
            (
                #"{ "media": "/abs/card.png", "at": [0, 1], "trackMatte": { "clip": "inner", "mode": "alpha" } }"#,
                #"{ "id": "inner", "title": "Hi", "style": "title", "at": [0, 1] }"#,
                #"clips[1].trackMatte.clip (image): no clip in the document has the id "inner", and a track matte is a clip of the same document"#
            ),
            (
                #"{ "id": "outer", "title": "Hi", "style": "title", "at": [0, 1] }"#,
                #"{ "media": "/abs/card.png", "at": [0, 1], "trackMatte": { "clip": "outer", "mode": "alpha" } }"#,
                #"clips[0].trackMatte.clip (image): no clip in the document has the id "outer", and a track matte is a clip of the same document"#
            )
        ]
    )
    func refusesTrackMatteAcrossCompound(
        outer: String,
        inner: String,
        message: String
    ) throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [
              { "media": { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "in": 0, "out": 1 } ],
                           "clips": [ \#(inner) ] }, "at": [0, 1] },
              \#(outer) ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: Fixture.json(document)) }
        #expect(error?.description.hasSuffix(message) == true)
    }

    // MARK: - Private
}

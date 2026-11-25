//
//  ParentFinderTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import Frames

@Suite("ParentFinder Tests")
struct ParentFinderTests {
    // MARK: - Property
    private let planner = Fixture.planner

    // MARK: - Initializer
    // MARK: - Test
    @Test("a three-deep chain names each parent, the last a storyline clip")
    func findsChain() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/screen.mp4" } ], "clips": [
              { "id": "card", "kind": "media", "media": "/abs/card.png", "at": [0, 1], "parent": "bar", "position": [0, 0] },
              { "id": "bar", "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "panel" },
              { "id": "panel", "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 20, 20], "at": [0, 1], "parent": "screen" } ] }
            """#

        // When
        let plan = try planner.plan(document: Fixture.json(document))

        // Then
        #expect(plan.clips.map(\.parent) == [
            .clip(index: 1, id: "bar"),
            .clip(index: 2, id: "panel"),
            .storyline(index: 0, id: "screen")
        ])
    }

    @Test(
        "a parent that names no clip, an audio clip, or a chain that comes back to itself stops",
        arguments: [
            (
                #"{ "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "missing" }"#,
                #"clips[0].parent (rect): no clip in the document has the id "missing""#
            ),
            (
                #"""
                { "id": "sound", "kind": "media", "media": "/abs/bgm.m4a", "at": [0, 1] },
                { "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "sound" }
                """#,
                #"clips[1].parent (rect): "sound" is an audio clip, which has no picture to be a parent"#
            ),
            (
                #"{ "id": "self", "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "self" }"#,
                #"clips[0]#self.parent (rect): the parent chain comes back to itself: "self" > "self""#
            ),
            (
                #"""
                { "id": "a", "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "c" },
                { "id": "b", "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "a" },
                { "id": "c", "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "b" }
                """#,
                #"clips[0]#a.parent (rect): the parent chain comes back to itself: "a" > "c" > "b" > "a""#
            )
        ]
    )
    func refusesParent(
        clips: String,
        message: String
    ) throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/screen.mp4" } ], "clips": [ \#(clips) ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try planner.plan(document: Fixture.json(document)) }
        #expect(error?.description == message)
    }

    // MARK: - Private
}

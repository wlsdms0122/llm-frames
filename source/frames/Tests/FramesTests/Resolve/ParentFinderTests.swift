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
    private let sut = ParentFinder()

    private let planner = Fixture.planner

    // MARK: - Initializer
    // MARK: - Test
    @Test("a chain that ends at a storyline clip or at a clip with no parent holds no cycle, however deep")
    func endsChain() {
        // Given
        // 0 names 1, 1 names 2, and 2 names a storyline clip or nothing.
        let parents: [Int?] = [1, 2, nil]

        // When
        let cycles = parents.indices.map { sut.cycle(from: $0, parents: parents) }

        // Then
        #expect(cycles == [nil, nil, nil])
    }

    @Test(
        "a chain that comes back to itself gives its cycle from the clip that comes first in the document",
        arguments: [
            ([0] as [Int?], 0, [0]),
            ([2, 3, 3, 1] as [Int?], 0, [1, 3]),
            ([2, 3, 3, 1] as [Int?], 3, [1, 3]),
            ([nil, 2, 3, 1] as [Int?], 3, [1, 2, 3])
        ]
    )
    func findsCycle(
        parents: [Int?],
        start: Int,
        cycle: [Int]
    ) {
        // When
        let found = sut.cycle(from: start, parents: parents)

        // Then
        #expect(found == cycle)
    }

    @Test("a three-deep chain names each parent, the last a storyline clip")
    func findsChain() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "id": "screen", "media": "/abs/screen.mp4" } ], "clips": [
              { "id": "card", "media": "/abs/card.png", "at": [0, 1], "parent": "bar", "position": [0, 0] },
              { "id": "bar", "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "panel" },
              { "id": "panel", "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 20, 20], "at": [0, 1], "parent": "screen" } ] }
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
                #"{ "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "missing" }"#,
                #"clips[0].parent (rect): no clip in the document has the id "missing""#
            ),
            (
                #"""
                { "id": "sound", "media": "/abs/bgm.m4a", "at": [0, 1] },
                { "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "sound" }
                """#,
                #"clips[1].parent (rect): "sound" is an audio clip, which has no picture to be a parent"#
            ),
            (
                #"{ "id": "self", "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "self" }"#,
                #"clips[0]#self.parent (rect): the parent chain comes back to itself: "self" > "self""#
            ),
            (
                #"""
                { "id": "a", "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "c" },
                { "id": "b", "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "a" },
                { "id": "c", "shape": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1], "parent": "b" }
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
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [ \#(clips) ] }
            """#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try planner.plan(document: Fixture.json(document)) }
        #expect(error?.description == message)
    }

    // MARK: - Private
}

//
//  OwnSpaceTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

@Suite("OwnSpace Tests")
struct OwnSpaceTests {
    // MARK: - Property
    private static let clips: [(String, OwnSpace)] = [
        (#"{ "media": "/abs/page.png", "at": [0, 1] }"#, .media),
        (#"{ "title": "a", "style": "title", "at": [0, 1] }"#, .box),
        (#"{ "shape": "rect", "stroke": { "width": 8 }, "width": 100, "height": 50, "at": [0, 1] }"#, .box),
        (#"{ "shape": "ellipse", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "at": [0, 1] }"#, .parent),
        (#"{ "shape": "path", "stroke": { "width": 8 }, "points": [[0, 0], [10, 10]], "at": [0, 1] }"#, .parent),
        (#"{ "adjust": "frames/warm", "at": [0, 1] }"#, .parent)
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a clip's own space is its media, its box for a title or box shape, else its parent's, as planned and read back",
        arguments: clips
    )
    func findsOwnSpace(
        clip: String,
        space: OwnSpace
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4" } ], "clips": [ \#(clip) ] }
            """#)

        // When
        let plan = try Fixture.documentPlanner.plan(document)
        let resolved = try ResolvedSequence(plan: plan, hashes: FileHashTable())

        // Then
        #expect(plan.time.clips[0].space == space)
        #expect(resolved.clips[0].space == space)
    }
}

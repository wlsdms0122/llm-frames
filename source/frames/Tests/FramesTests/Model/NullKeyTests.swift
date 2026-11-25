//
//  NullKeyTests.swift
//  FramesTests
//
//  Created by JSilver on 11/25/26.
//

import Testing

@testable import Frames

@Suite("Null Key Tests")
struct NullKeyTests {
    // MARK: - Property
    private static let allowed = "id, metadata, at, parent, motionBlur, track, animation, keyframes, null, area, width, height, placement, position, anchor, scale, rotation"

    private let sut = KeyChecker(mediaKinds: Fixture.mediaKinds)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a null passes the key tables with every key it takes, as a connected clip and as a sequence clip")
    func takesNullKeys() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence",
              "storyline": [ { "id": "screen", "kind": "media", "media": "/abs/run.mp4", "connected": [
                { "id": "carrier", "kind": "null", "parent": "screen", "area": [0, 0, 10, 10], "anchor": "center",
                  "track": { "time": 1, "frames": [ { "time": 1, "quad": [[0, 0], [10, 0], [10, 10], [0, 10]] } ] } } ] } ],
              "clips": [
                { "id": "box", "metadata": { "note": "a" }, "at": [0, 2], "kind": "null", "width": 200, "height": 100,
                  "placement": "center", "anchor": "top-left", "scale": 2, "rotation": 30, "motionBlur": true, "animation": "none" },
                { "kind": "null", "parent": "box", "at": [0, 2],
                  "keyframes": [ { "at": 0, "width": 10, "height": 10, "position": [0, 0], "scale": 1, "rotation": 0 },
                                 { "at": 1, "width": 20, "height": 20, "position": [10, 10], "scale": [2, 1], "rotation": 90 } ] }
              ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a null on the storyline, a key of appearance or compositing on a null and a null that is not true stop",
        arguments: [
            (
                #"{ "storyline": [ { "kind": "null", "duration": 2 } ] }"#,
                #"storyline[0] (storyline clip): unknown key "null". Allowed: media, solid"#
            ),
            (
                #"{ "clips": [ { "kind": "null", "width": 10, "height": 10, "opacity": 0 } ] }"#,
                #"clips[0] (null): unknown key "opacity". Allowed: \#(allowed)"#
            ),
            (
                #"{ "clips": [ { "kind": "null", "width": 10, "height": 10, "cornerPin": [[0, 0], [10, 0], [10, 10], [0, 10]] } ] }"#,
                #"clips[0] (null): unknown key "cornerPin". Allowed: \#(allowed)"#
            ),
            (
                #"{ "clips": [ { "kind": "null", "width": 10, "height": 10, "lane": 2 } ] }"#,
                #"clips[0] (null): unknown key "lane". Allowed: \#(allowed)"#
            ),
            (
                #"{ "clips": [ { "kind": "null", "width": 10, "height": 10, "style": "cover" } ] }"#,
                #"clips[0] (null): unknown key "style". Allowed: \#(allowed)"#
            ),
            (
                #"{ "clips": [ { "kind": "null", "width": 10, "height": 10, "mask": { "rect": [0, 0, 5, 5] } } ] }"#,
                #"clips[0] (null): unknown key "mask". Allowed: \#(allowed)"#
            ),
            (
                #"{ "clips": [ { "kind": "null", "width": 10, "height": 10, "keyframes": [ { "at": 0, "opacity": 0 } ] } ] }"#,
                #"clips[0].keyframes[0] (keyframe): unknown key "opacity". Allowed: at, ease, area, width, height, position, scale, rotation"#
            ),
            (
                #"{ "clips": [ { "null": false, "width": 10, "height": 10 } ] }"#,
                "clips[0].null (null): expected true, found false"
            )
        ]
    )
    func refusesNullKeys(
        body: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "# + body.dropFirst())

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }

    // MARK: - Private
}

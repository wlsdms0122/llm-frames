//
//  CornerRadiusCheckTests.swift
//  FramesTests
//
//  Created by JSilver on 11/24/26.
//

import Testing

@testable import Frames

// A `radius` is one length for every corner or a list of four, wherever a box takes it, and a list of another length
// or a negative corner stops (FRAMES-11 Shapes).
@Suite("Corner radius check Tests")
struct CornerRadiusCheckTests {
    // MARK: - Property
    private let sut = KeyChecker(mediaKinds: Fixture.mediaKinds)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "every box that takes a radius takes one length or four",
        arguments: [
            #"{ "clips": [ { "kind": "rect", "area": [0, 0, 10, 10], "fill": "accent", "radius": [1, 2, 3, 4] } ] }"#,
            #"{ "clips": [ { "kind": "rect", "area": [0, 0, 10, 10], "fill": "accent", "radius": 2 } ] }"#,
            #"{ "clips": [ { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "radius": [0, 24, 0, 24] } ] }"#,
            #"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "radius": [12, 12, 0, 0] } ] }"#,
            #"{ "clips": [ { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "mask": { "kind": "rect", "area": [0, 0, 10, 10], "radius": [1, 2, 3, 4] } } ] }"#,
            #"{ "theme": { "shapes": { "tab": { "fill": "accent", "radius": [8, 8, 0, 0] } } } }"#,
            #"{ "theme": { "styles": { "chip": { "size": 40, "background": { "radius": [4, 4, 0, 0] }, "highlight": { "radius": [0, 6, 0, 6] } } } } }"#,
            #"{ "clips": [ { "kind": "rect", "area": [0, 0, 10, 10], "fill": "accent", "keyframes": [ { "at": 0, "radius": 4 }, { "at": 1, "radius": [0, 4, 8, 12] } ] } ] }"#,
            #"{ "clips": [ { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "mask": { "kind": "rect", "area": [0, 0, 10, 10] }, "keyframes": [ { "at": 0, "mask": { "radius": [0, 1, 2, 3] } } ] } ] }"#
        ]
    )
    func takesOneOrFourRadii(body: String) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "# + body.dropFirst())

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a radius list of another length than four stops, and so does a negative corner, naming its place",
        arguments: [
            (
                #"{ "clips": [ { "kind": "rect", "area": [0, 0, 10, 10], "fill": "accent", "radius": [1, 2, 3] } ] }"#,
                "clips[0].radius (rect): expected a list of 4 numbers, each 0 or more, found a list of 3"
            ),
            (
                #"{ "clips": [ { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "radius": [1, 2] } ] }"#,
                "clips[0].radius (image): expected a list of 4 numbers, each 0 or more, found a list of 2"
            ),
            (
                #"{ "clips": [ { "kind": "rect", "area": [0, 0, 10, 10], "fill": "accent", "radius": [1, -2, 3, 4] } ] }"#,
                "clips[0].radius[1] (rect): -2 is not 0 or more"
            ),
            (
                #"{ "clips": [ { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "mask": { "kind": "rect", "area": [0, 0, 10, 10], "radius": [1, 2, 3, 4, 5] } } ] }"#,
                "clips[0].mask.radius (rect mask): expected a list of 4 numbers, each 0 or more, found a list of 5"
            )
        ]
    )
    func refusesOtherLengths(
        body: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "# + body.dropFirst())

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description == message)
    }
}

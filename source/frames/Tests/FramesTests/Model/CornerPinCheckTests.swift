//
//  CornerPinCheckTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

@Suite("CornerPin Check Tests")
struct CornerPinCheckTests {
    // MARK: - Property
    private let sut = KeyChecker(mediaKinds: Fixture.mediaKinds)
    private static let pin = "[[100, 100], [500, 120], [480, 400], [120, 380]]"

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a title, a media clip with a picture, a rect or ellipse by its box and a storyline clip with media take a corner pin, statically and in a keyframe",
        arguments: [
            #"{ "title": "Hi", "style": "subtitle", "at": [0, 1], "cornerPin": PIN }"#,
            #"{ "media": "/abs/run.mp4", "at": 0, "cornerPin": PIN }"#,
            #"{ "media": "/abs/card.png", "at": [0, 1], "cornerPin": PIN }"#,
            #"{ "shape": "rect", "fill": "accent", "width": 10, "height": 10, "at": [0, 1], "cornerPin": PIN }"#,
            #"{ "shape": "ellipse", "fill": "accent", "width": 10, "height": 10, "at": [0, 1], "keyframes": [ { "at": 0, "cornerPin": PIN } ] }"#,
            #"{ "media": "/abs/card.png", "at": [0, 1], "keyframes": [ { "at": 0, "cornerPin": PIN }, { "at": 1, "cornerPin": PIN } ] }"#
        ]
    )
    func takesCornerPin(clip: String) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [
              { "media": "/abs/run.mp4", "cornerPin": PIN, "connected": [ CLIP ] },
              { "media": "/abs/card.png", "duration": 1, "keyframes": [ { "at": 0, "cornerPin": PIN } ] }
            ] }
            """#.replacingOccurrences(of: "CLIP", with: clip).replacingOccurrences(of: "PIN", with: Self.pin))

        // When, Then
        try sut.check(document: document)
    }

    @Test("a corner pin takes every point form a position takes, a point of an area included")
    func takesPointForms() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "connected": [
              { "kind": "media", "media": "/abs/card.png", "at": [0, 1],
                "cornerPin": [ { "area": { "clip": "box" }, "point": "top-left" }, [500, 120], [480, 400], { "area": [0, 0, 10, 10], "point": "bottom" } ] } ] } ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a corner pin is a list of four points",
        arguments: [
            ("[[100, 100], [500, 120], [480, 400]]", "storyline[0].connected[0].cornerPin (image): expected a list of four points"),
            ("[[100, 100], [500, 120], [480, 400], [120, 380], [0, 0]]", "storyline[0].connected[0].cornerPin (image): expected a list of four points"),
            ("[[100, 100], [500, 120], [480, 400], [120]]", "storyline[0].connected[0].cornerPin[3] (image): expected")
        ]
    )
    func refusesOtherCount(
        pin: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "connected": [
              { "kind": "media", "media": "/abs/card.png", "at": [0, 1], "cornerPin": \#(pin) } ] } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(message) == true)
    }

    @Test(
        "a solid, an adjustment clip, an audio clip and a path take no corner pin",
        arguments: [
            (#"{ "solid": "accent", "duration": 1, "cornerPin": PIN }"#, "storyline[1] (solid)"),
            (#"{ "media": "/abs/run.mp4", "connected": [ { "adjust": "blur", "at": [0, 1], "cornerPin": PIN } ] }"#, "storyline[1].connected[0] (adjustment)"),
            (#"{ "media": "/abs/run.mp4", "connected": [ { "media": "/abs/bgm.m4a", "at": 0, "cornerPin": PIN } ] }"#, "storyline[1].connected[0] (audio)"),
            (#"{ "media": "/abs/run.mp4", "connected": [ { "shape": "path", "fill": "accent", "points": [[0, 0], [10, 0], [0, 10]], "at": [0, 1], "cornerPin": PIN } ] }"#, "storyline[1].connected[0] (path)")
        ]
    )
    func refusesCornerPin(
        clip: String,
        place: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" }, CLIP ] }
            """#.replacingOccurrences(of: "CLIP", with: clip).replacingOccurrences(of: "PIN", with: Self.pin))

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasPrefix(#"\#(place): unknown key "cornerPin""#) == true)
    }

    @Test("a corner pin sits in a clip's key list in the specification's order")
    func listsCornerPinInOrder() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "connected": [ { "kind": "title", "text": "Hi", "at": [0, 1], "pin": 1 } ] } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }
        #expect(error?.description.hasSuffix("width, placement, position, anchor, scale, rotation, cornerPin") == true)
    }

    // MARK: - Private
}

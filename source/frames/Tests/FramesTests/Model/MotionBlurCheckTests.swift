//
//  MotionBlurCheckTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Testing

@testable import Frames

@Suite("MotionBlurCheck Tests")
struct MotionBlurCheckTests {
    // MARK: - Property
    private let sut = KeyChecker(mediaKinds: Fixture.mediaKinds)

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a shutter within its ranges passes, each key optional",
        arguments: [
            #"{}"#,
            #"{ "shutterAngle": 720, "shutterPhase": -720, "samplesPerFrame": 256 }"#,
            #"{ "shutterAngle": 0.5, "shutterPhase": -0.5, "samplesPerFrame": 2 }"#,
            #"{ "shutterAngle": 360 }"#,
            #"{ "shutterPhase": -180 }"#,
            #"{ "samplesPerFrame": 64 }"#
        ]
    )
    func acceptsShutter(shutter: String) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "format": { "motionBlur": \#(shutter) }, "storyline": [ { "media": "/abs/run.mp4" } ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test(
        "a shutter value outside its range, of another type or not whole where a count is stops at its key",
        arguments: [
            (#"{ "shutterAngle": 0 }"#, "format.motionBlur.shutterAngle (motion blur): 0 is not above 0 and at most 720"),
            (#"{ "shutterAngle": 721 }"#, "format.motionBlur.shutterAngle (motion blur): 721 is not above 0 and at most 720"),
            (#"{ "shutterAngle": "180" }"#, #"format.motionBlur.shutterAngle (motion blur): expected a number above 0 and at most 720, found "180""#),
            (#"{ "shutterPhase": 10 }"#, "format.motionBlur.shutterPhase (motion blur): 10 is not within -180 to 0"),
            (#"{ "shutterPhase": true }"#, "format.motionBlur.shutterPhase (motion blur): expected a number, found true"),
            (#"{ "samplesPerFrame": 1 }"#, "format.motionBlur.samplesPerFrame (motion blur): 1 is not within 2 to 256"),
            (#"{ "samplesPerFrame": 257 }"#, "format.motionBlur.samplesPerFrame (motion blur): 257 is not within 2 to 256"),
            (#"{ "samplesPerFrame": 16.5 }"#, "format.motionBlur.samplesPerFrame (motion blur): expected a whole number, found 16.5"),
            (#"true"#, "format.motionBlur (format): expected an object (motion blur), found true")
        ]
    )
    func refusesShutterValue(
        shutter: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "format": { "motionBlur": \#(shutter) }, "storyline": [ { "media": "/abs/run.mp4" } ] }
            """#)

        // When
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }

        // Then
        #expect(error?.description == message)
    }

    @Test(
        "a shutter phase is read against the angle in effect, the default angle where none is written",
        arguments: [
            (#"{ "shutterPhase": -200 }"#, "-200 is not within -180 to 0"),
            (#"{ "shutterAngle": 90, "shutterPhase": -91 }"#, "-91 is not within -90 to 0")
        ]
    )
    func refusesPhaseBeyondAngle(
        shutter: String,
        refusal: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "format": { "motionBlur": \#(shutter) }, "storyline": [ { "media": "/abs/run.mp4" } ] }
            """#)

        // When
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }

        // Then
        #expect(error?.description == "format.motionBlur.shutterPhase (motion blur): \(refusal)")
    }

    @Test("a phase under an angle that takes it passes")
    func acceptsPhaseWithinAngle() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "format": { "motionBlur": { "shutterAngle": 300, "shutterPhase": -200 } },
              "storyline": [ { "media": "/abs/run.mp4" } ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test("a shutter takes no other key")
    func refusesUnknownShutterKey() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "format": { "motionBlur": { "shutterSpeed": 50 } }, "storyline": [ { "media": "/abs/run.mp4" } ] }
            """#)

        // When
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }

        // Then
        #expect(error?.description == #"format.motionBlur (motion blur): unknown key "shutterSpeed". Allowed: shutterAngle, shutterPhase, samplesPerFrame"#)
    }

    @Test("a compound clip's own format takes a shutter")
    func acceptsNestedShutter() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": { "kind": "sequence", "format": { "motionBlur": { "shutterAngle": 90 } },
              "storyline": [ { "media": "/abs/run.mp4" } ] } } ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test("every storyline clip and every clip with a picture takes motionBlur")
    func acceptsClipSwitch() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence",
              "storyline": [
                { "media": "/abs/run.mp4", "motionBlur": true,
                  "connected": [ { "at": [0, 1], "title": "Hi", "style": "title", "motionBlur": true } ] },
                { "media": "/abs/card.png", "duration": 1, "motionBlur": false },
                { "solid": "#000000", "duration": 1, "motionBlur": true }
              ],
              "clips": [
                { "at": [0, 1], "shape": "rect", "area": [0, 0, 10, 10], "fill": "accent", "motionBlur": true },
                { "at": [0, 1], "media": "/abs/light-leak.mov", "motionBlur": true },
                { "at": [0, 1], "media": "/abs/log.png", "motionBlur": true },
                { "at": [0, 1], "adjust": "frames/vivid", "motionBlur": true }
              ] }
            """#)

        // When, Then
        try sut.check(document: document)
    }

    @Test("motionBlur is true or false")
    func refusesNonBooleanSwitch() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "motionBlur": 1 } ] }
            """#)

        // When
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }

        // Then
        #expect(error?.description == "storyline[0].motionBlur (video): expected true or false, found 1")
    }

    @Test(
        "motionBlur stops as an unknown key on an audio clip, in a keyframe, and in a theme's defaults and styles",
        arguments: [
            (
                #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ { "media": "/abs/bgm.m4a", "motionBlur": true } ] }"#,
                #"clips[0] (audio): unknown key "motionBlur"."#
            ),
            (
                #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "keyframes": [ { "at": 0, "motionBlur": true } ] } ] }"#,
                #"storyline[0].keyframes[0] (keyframe): unknown key "motionBlur"."#
            ),
            (
                #"{ "kind": "sequence", "theme": { "defaults": { "motionBlur": true } }, "storyline": [ { "media": "/abs/run.mp4" } ] }"#,
                #"theme.defaults (defaults): unknown key "motionBlur"."#
            ),
            (
                #"{ "kind": "sequence", "theme": { "styles": { "title": { "motionBlur": true } } }, "storyline": [ { "media": "/abs/run.mp4" } ] }"#,
                #"theme.styles.title (style): unknown key "motionBlur"."#
            )
        ]
    )
    func refusesSwitchWhereNotTaken(
        document: String,
        prefix: String
    ) throws {
        // Given
        let document = try Fixture.json(document)

        // When
        let error = #expect(throws: ModelError.self) { try sut.check(document: document) }

        // Then
        #expect(error?.description.hasPrefix(prefix) == true, "\(error?.description ?? "")")
    }

    // MARK: - Private
}

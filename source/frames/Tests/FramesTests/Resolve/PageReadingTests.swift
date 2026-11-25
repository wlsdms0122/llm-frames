//
//  PageReadingTests.swift
//  FramesTests
//
//  Created by JSilver on 11/22/26.
//

import Testing

@testable import Frames

@Suite("Page Reading Tests")
struct PageReadingTests {
    // MARK: - Property
    private let sut = Fixture.planner

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "toneMap on a clip whose media is a page stops as a key of another media row",
        arguments: [
            (
                #"{ "storyline": [ { "kind": "media", "media": { "file": "/abs/deck.pdf", "page": 2 }, "duration": 2, "toneMap": false } ] }"#,
                #"storyline[0] (page): unknown key "toneMap". Allowed: id, metadata, kind, media, colorSpace, duration, crop, filter, transition, anchor, position, scale, rotation, cornerPin, opacity, blend, motionBlur, mask, trackMatte, radius, border, shadow, keyframes, connected"#
            ),
            (
                #"{ "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "connected": [ { "kind": "media", "media": "/abs/logo.pdf", "at": [0, 1], "toneMap": true } ] } ] }"#,
                #"storyline[0].connected[0] (page): unknown key "toneMap". Allowed: id, metadata, kind, at, lane, parent, opacity, blend, motionBlur, mask, trackMatte, track, animation, keyframes, media, colorSpace, placement, position, anchor, scale, rotation, cornerPin, crop, conform, filter, width, height, radius, border, shadow"#
            )
        ]
    )
    func refusesToneMapOnPage(
        body: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "# + body.dropFirst())

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.plan(document: document) }
        #expect(error?.description == message)
    }

    @Test("a page clip's colorSpace takes the spaces of standard dynamic range, and an HDR name stops", arguments: ["rec2100-pq", "rec2100-hlg"])
    func refusesHighDynamicRangeColorSpace(name: String) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": { "file": "/abs/deck.pdf", "page": 1 }, "duration": 2, "colorSpace": "\#(name)" } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.plan(document: document) }
        #expect(error?.description == #"storyline[0].colorSpace (page): unknown value "\#(name)". Allowed: srgb, display-p3, rec2020, rec709"#)
    }

    @Test("a page clip takes every colour space of standard dynamic range")
    func takesStandardDynamicRangeColorSpace() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": { "file": "/abs/deck.pdf", "page": 1 }, "duration": 2, "colorSpace": "rec709" } ] }"#)

        // When, Then
        #expect(throws: Never.self) { try sut.plan(document: document) }
    }

    @Test(
        "an image parameter given a page makes its clips clips of a page, so toneMap and an HDR colorSpace on them stop",
        arguments: [
            (
                #""toneMap": false"#,
                #"storyline[0] (page): unknown key "toneMap". Allowed: id, metadata, kind, media, colorSpace, duration, crop, filter, transition, anchor, position, scale, rotation, cornerPin, opacity, blend, motionBlur, mask, trackMatte, radius, border, shadow, keyframes, connected"#
            ),
            (
                #""colorSpace": "rec2100-pq""#,
                #"storyline[0].colorSpace (page): unknown value "rec2100-pq". Allowed: srgb, display-p3, rec2020, rec709"#
            )
        ]
    )
    func refusesHighDynamicRangeKeysOnPageArgument(
        key: String,
        message: String
    ) throws {
        // Given
        let template = try Fixture.json(#"""
            { "kind": "sequence", "params": { "still": { "type": "image", "description": "the still" } },
              "storyline": [ { "kind": "media", "media": { "param": "still" }, "duration": 2, \#(key) } ] }
            """#)
        let arguments = ArgumentFile(name: "", value: try Fixture.json(#"{ "still": { "file": "/abs/deck.pdf", "page": 4 } }"#))

        // When, Then
        let error = #expect(throws: ModelError.self) { try Fixture.documentPlanner.plan(template, arguments: arguments) }
        #expect(error?.description == message)
    }

    @Test("a transition's page cover read in an HDR colour space stops", arguments: [ColorSpace.rec2100PQ, .rec2100HLG])
    func refusesHighDynamicRangePageCover(colorSpace: ColorSpace) throws {
        // Given
        let cover = Cover(source: .page("/abs/deck.pdf", page: 3), colorSpace: colorSpace, span: Span(ease: .linear, keys: []))
        let sut = TimePlanner(mediaFacts: Fixture.mediaFacts, presets: presets(cover: cover, matte: nil), library: Fixture.library)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.plan(document: transitionDocument) }
        #expect(error?.description == #"storyline[1].transition (solid): media "/abs/deck.pdf" page 3 is not HDR, so it is read in a colour space of standard dynamic range, not "\#(colorSpace.rawValue)". Allowed: srgb, display-p3, rec2020, rec709"#)
    }

    @Test("a transition's page matte read in an HDR colour space stops, a one-page PDF named as a file included")
    func refusesHighDynamicRangePageMatte() throws {
        // Given
        let matte = Matte(media: "/abs/logo.pdf", colorSpace: .rec2100PQ, softness: 0, isInverted: false, ease: .linear)
        let sut = TimePlanner(mediaFacts: Fixture.mediaFacts, presets: presets(cover: nil, matte: matte), library: Fixture.library)

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.plan(document: transitionDocument) }
        #expect(error?.description == #"storyline[1].transition (solid): media "/abs/logo.pdf" page 1 is not HDR, so it is read in a colour space of standard dynamic range, not "rec2100-pq". Allowed: srgb, display-p3, rec2020, rec709"#)
    }

    @Test("ocr of a page read in an HDR colour space stops")
    func refusesHighDynamicRangePageInOCR() throws {
        // Given
        let sut = OCRReporter(mediaFacts: Fixture.mediaFacts, ocr: Fixture.ocr, languages: nil)

        // When, Then
        let error = #expect(throws: AnalysisError.self) { try sut.report(of: "/abs/deck.pdf", page: 2, colorSpace: .rec2100HLG) }
        #expect(error?.description == #"--color-space: media "/abs/deck.pdf" page 2 is not HDR, so it is read in a colour space of standard dynamic range, not "rec2100-hlg". Allowed: srgb, display-p3, rec2020, rec709"#)
    }

    // MARK: - Private
    private var transitionDocument: JSONValue {
        get throws {
            try Fixture.json(#"""
                { "kind": "sequence", "storyline": [ { "kind": "solid", "color": "#000000", "duration": 2 },
                                                     { "kind": "solid", "color": "#FFFFFF", "duration": 2, "transition": "stinger" } ] }
                """#)
        }
    }

    // A preset `stinger` with that cover and that matte.
    private func presets(
        cover: Cover?,
        matte: Matte?
    ) -> PresetTable {
        PresetTable(
            transitions: [
                "stinger": TransitionPreset(
                    description: "",
                    seconds: 1,
                    over: .incoming,
                    audio: .constantPower,
                    incoming: nil,
                    outgoing: nil,
                    cover: cover,
                    matte: matte
                )
            ],
            animations: Fixture.presets.animations,
            filters: Fixture.presets.filters
        )
    }
}

//
//  DefaultFilterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

// The document's theme names `grade` as the default filter. The output is 1080 wide, so the blur's theme length is
// scaled by 1080 / 1206.
@Suite("DefaultFilter Tests")
struct DefaultFilterTests {
    // MARK: - Property
    private let grade: [FilterOperation] = [.saturation(amount: 1.25), .blur(radius: 4 * (1080.0 / 1206))]

    // MARK: - Initializer
    // MARK: - Test
    @Test("media that writes no filter takes the theme's default, on the storyline and as a connected clip")
    func appliesDefaultToMedia() throws {
        // When
        let plan = try plan(#"""
            { "media": "/abs/run.mp4", "in": 0, "out": 3,
              "connected": [ { "media": "/abs/card.png", "at": [0, 1] }, { "media": "/abs/card.png", "at": [0, 1], "filter": "none" } ] }
            """#)

        // Then
        #expect(plan.storyline[0].filter == grade)
        #expect(plan.clips[0].appearance.filter == grade)
        #expect(plan.clips[1].appearance.filter == [])
    }

    @Test("a title takes no filter, since only media takes the default")
    func leavesTitleUnfiltered() throws {
        // When
        let plan = try plan(#"""
            { "media": "/abs/run.mp4", "in": 0, "out": 3, "connected": [ { "title": "Hi", "style": "subtitle", "at": [0, 1] } ] }
            """#)

        // Then
        #expect(plan.clips[0].appearance.filter == [])
    }

    @Test("a compound clip takes no default filter, since its own clips already took theirs")
    func leavesCompoundClipUnfiltered() throws {
        // When
        let plan = try plan(#"""
            { "media": { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3 } ] } }
            """#)

        // Then
        #expect(plan.storyline[0].filter == [])
        guard case let .sequence(nested) = plan.storyline[0].nested else {
            Issue.record("the compound clip has no nested sequence")
            return
        }
        #expect(nested.storyline[0].filter == grade)
    }

    @Test("a template instance takes no default filter, since its own clips already took theirs")
    func leavesTemplateInstanceUnfiltered() throws {
        // Given
        let directory = try PackDirectory()
        try directory.addPack("shorts")
        try directory.write(
            #"{ "kind": "sequence", "params": { "clip": { "type": "video" } }, "storyline": [ { "media": { "param": "clip" }, "in": 0, "out": 3 } ] }"#,
            in: "shorts",
            at: "templates/still.json"
        )
        let library = directory.library()
        let planner = TimePlanner(mediaFacts: Fixture.mediaFacts, presets: Fixture.presets, library: library)
        let sut = SequencePlanner(
            ocr: Fixture.ocr,
            tracker: Fixture.tracker,
            shaper: Fixture.shaper,
            presets: Fixture.presets,
            library: library
        )

        // When
        let plan = try sut.plan(planner.plan(document: document(
            #"{ "media": { "template": "shorts/still", "args": { "clip": "/abs/run.mp4" } } }"#
        )))

        // Then
        #expect(plan.storyline[0].filter == [])
    }

    // MARK: - Private
    private func plan(_ storylineClip: String) throws -> SequencePlan {
        try Fixture.sequencePlanner.plan(Fixture.planner.plan(document: document(storylineClip)))
    }

    private func document(_ storylineClip: String) throws -> JSONValue {
        try Fixture.json(#"""
            { "kind": "sequence", "theme": { "defaults": { "filter": "grade" } }, "storyline": [ \#(storylineClip) ] }
            """#)
    }
}

//
//  DefaultFilterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

// The document's theme names `grade` as the default filter. The output is 1080 wide, so the blur's theme length is
// scaled by 1080 / 1920. `film` is a preset whose LUT names no file.
@Suite("DefaultFilter Tests")
struct DefaultFilterTests {
    // MARK: - Property
    private let grade = [FilterEntry(operations: [.saturation(amount: 1.25), .blur(radius: 4 * (1080.0 / 1920))])]
    private let presets = PresetTable(
        transitions: Fixture.presets.transitions,
        animations: Fixture.presets.animations,
        filters: ["film": #"{"description": "", "ops": [{"op": "lut", "file": "film.cube", "amount": 1}]}"#]
    )

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
        #expect(plan.storyline[0].filter.filter() == grade)
        #expect(plan.clips[0].appearance.filter.filter() == grade)
        #expect(plan.clips[1].appearance.filter == .off)
    }

    @Test("a title takes no filter, since only media takes the default")
    func leavesTitleUnfiltered() throws {
        // When
        let plan = try plan(#"""
            { "media": "/abs/run.mp4", "in": 0, "out": 3, "connected": [ { "title": "Hi", "style": "subtitle", "at": [0, 1] } ] }
            """#)

        // Then
        #expect(plan.clips[0].appearance.filter == .off)
    }

    @Test("a compound clip takes no default filter, since its own clips already took theirs")
    func leavesCompoundClipUnfiltered() throws {
        // When
        let plan = try plan(#"""
            { "media": { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3 } ] } }
            """#)

        // Then
        #expect(plan.storyline[0].filter == .off)
        let nested = try #require(plan.storyline[0].nested)
        #expect(nested.storyline[0].filter.filter() == grade)
    }

    @Test("a template instance takes no default filter, since its own clips already took theirs")
    func leavesTemplateInstanceUnfiltered() throws {
        // Given
        let directory = try PackDirectory()
        try directory.addPack("shorts")
        try directory.write(
            #"{ "kind": "sequence", "params": { "clip": { "type": "video", "description": "the clip" } }, "storyline": [ { "media": { "param": "clip" }, "in": 0, "out": 3 } ] }"#,
            in: "shorts",
            at: "templates/still.json"
        )
        let library = directory.library()
        let planner = TimePlanner(mediaFacts: Fixture.mediaFacts, presets: Fixture.presets, library: library)
        let sut = SequencePlanner(
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
        #expect(plan.storyline[0].filter == .off)
    }

    @Test("an audio clip takes no default filter, since nothing draws it, so a default it could not use does not stop")
    func leavesAudioUnfiltered() throws {
        // When
        let plan = try filmPlan(#"""
            { "kind": "sequence", "theme": { "defaults": { "filter": "film" } }, "format": { "size": [1080, 1920] },
              "storyline": [ { "solid": "#000000", "duration": 3 } ], "clips": [ { "media": "/abs/bgm.m4a", "at": 0 } ] }
            """#)

        // Then
        #expect(plan.clips[0].appearance.filter == .off)
    }

    @Test("a default filter whose values do not resolve stops where the theme names it")
    func refusesDefaultAtThemePlace() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "theme": { "defaults": { "filter": ["film"] } },
              "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 3 } ] }
            """#
        let place = Place.root.appending(key: "theme").appending(key: "defaults").appending(key: "filter").appending(index: 0)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try filmPlan(document) }
        #expect(error == .unknownPresetFile(place: place, kind: .themeDefaults, name: "film.cube"))
    }

    // MARK: - Private
    private func plan(_ storylineClip: String) throws -> SequencePlan {
        try Fixture.sequencePlanner.plan(Fixture.planner.plan(document: document(storylineClip)))
    }

    private func document(_ storylineClip: String) throws -> JSONValue {
        try Fixture.json(#"""
            { "kind": "sequence", "theme": { "defaults": { "filter": "mine/grade" } }, "storyline": [ \#(storylineClip) ] }
            """#)
    }

    private func filmPlan(_ document: String) throws -> SequencePlan {
        let planner = TimePlanner(mediaFacts: Fixture.mediaFacts, presets: presets, library: Fixture.library)
        let sut = SequencePlanner(
            tracker: Fixture.tracker,
            shaper: Fixture.shaper,
            presets: presets,
            library: Fixture.library
        )

        return try sut.plan(planner.plan(document: Fixture.json(document)))
    }
}

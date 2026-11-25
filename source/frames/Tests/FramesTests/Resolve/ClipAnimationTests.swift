//
//  ClipAnimationTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("Clip Animation Tests")
struct ClipAnimationTests {
    // MARK: - Property
    private let sut = Fixture.planner

    // MARK: - Initializer
    // MARK: - Test
    @Test("a connected clip without at keeps its animation's entrance and exit, whether it has a parent or not")
    func keepsEntranceAndExitWithoutAt() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "id": "run", "kind": "media", "media": "/abs/run.mp4", "connected": [
              { "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "parent": "run", "animation": "frames/pulse" },
              { "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "animation": "frames/pulse" },
              { "kind": "title", "text": "a", "style": "subtitle", "parent": "run", "position": [0, 0], "animation": "frames/pulse" }
            ] } ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips.map { $0.animation.entrance?.preset } == ["frames/pulse", "frames/pulse", "frames/pulse"])
        #expect(plan.clips.map { $0.animation.loop?.preset } == ["frames/pulse", "frames/pulse", "frames/pulse"])
        #expect(plan.clips.map { $0.animation.exit?.preset } == ["frames/pulse", "frames/pulse", "frames/pulse"])
    }

    @Test("a clip that names no animation takes the theme's default for its kind, a title the one for its style and every shape the one for shapes")
    func takesDefaultAnimation() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence",
              "theme": { "defaults": { "animation": { "title": { "subtitle": "frames/pop" }, "shape": "frames/wipe", "media": "frames/fade", "adjustment": "frames/pop" } } },
              "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ],
              "clips": [
                { "at": [0, 1], "kind": "title", "text": "a", "style": "subtitle" },
                { "at": [0, 1], "kind": "title", "text": "b", "style": "headline" },
                { "at": [0, 1], "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10] },
                { "at": [0, 1], "kind": "media", "media": "/abs/log.png" },
                { "at": [0, 1], "kind": "media", "media": "/abs/log.png", "animation": "none" },
                { "kind": "media", "media": "/abs/bgm.m4a" },
                { "at": [0, 1], "kind": "ellipse", "fill": "accent", "area": [0, 0, 10, 10] },
                { "at": [0, 1], "kind": "path", "stroke": { "width": 8 }, "points": [[0, 0], [10, 10]] },
                { "at": [0, 1], "kind": "adjustment", "adjust": "frames/vivid" }
              ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips.map { $0.animation.entrance?.preset } == [
            "frames/pop", nil, "frames/wipe", "frames/fade", nil, nil, "frames/wipe", "frames/wipe", "frames/pop"
        ])
        #expect(plan.clips[5].animation == .none)
    }

    @Test("{entrance, exit} takes the entrance from one preset and the exit from another, and none on a side leaves it out")
    func splitsAnimationChoice() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [
              { "at": [0, 1], "kind": "media", "media": "/abs/log.png", "animation": { "entrance": "frames/pop", "exit": "frames/fade" } },
              { "at": [0, 1], "kind": "media", "media": "/abs/log.png", "animation": { "entrance": "none", "exit": "frames/pulse" } }
            ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips[0].animation.entrance?.preset == "frames/pop")
        #expect(plan.clips[0].animation.exit?.preset == "frames/fade")
        #expect(plan.clips[1].animation.entrance == nil)
        #expect(plan.clips[1].animation.loop == nil)
        #expect(plan.clips[1].animation.exit?.span.length == 0.25)
    }

    @Test("sides written over a default keep its loop and its other side, and over none play only the spans they write")
    func replacesSidesOfDefault() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence",
              "theme": { "defaults": { "animation": { "media": "frames/pulse", "shape": "none" } } },
              "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ],
              "clips": [
                { "at": [0, 4], "kind": "media", "media": "/abs/log.png", "animation": { "entrance": "frames/pop", "exit": "frames/fade" } },
                { "at": [0, 4], "kind": "media", "media": "/abs/log.png", "animation": { "exit": "none" } },
                { "at": [0, 4], "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "animation": { "entrance": "frames/pop", "exit": "frames/fade" } }
              ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips.map(\.animation.entrance?.preset) == ["frames/pop", "frames/pulse", "frames/pop"])
        #expect(plan.clips.map(\.animation.loop?.preset) == ["frames/pulse", "frames/pulse", nil])
        #expect(plan.clips.map(\.animation.exit?.preset) == ["frames/fade", nil, "frames/fade"])
    }

    @Test("a title's `{\"by\": \"word\"}` plays its default animation by word, and a written `stagger` replaces the unit's default")
    func playsByUnit() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence",
              "theme": { "defaults": { "animation": { "title": { "subtitle": "frames/pop" } } } },
              "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ],
              "clips": [
                { "at": [0, 1], "kind": "title", "text": "a", "style": "subtitle", "animation": { "by": "word" } },
                { "at": [0, 1], "kind": "title", "text": "b", "style": "headline", "animation": { "preset": "frames/fade", "by": "character", "stagger": 0.1 } },
                { "at": [0, 1], "kind": "title", "text": "c", "style": "headline", "animation": { "preset": "frames/fade", "by": "line" } },
                { "at": [0, 1], "kind": "title", "text": "d", "style": "headline", "animation": "frames/fade" }
              ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips[0].animation.entrance?.preset == "frames/pop")
        #expect(plan.clips.map(\.animation.units) == [
            UnitStagger(by: .word, stagger: 0.12),
            UnitStagger(by: .character, stagger: 0.1),
            UnitStagger(by: .line, stagger: 0.3),
            nil
        ])
    }

    @Test("`{entrance, exit}` plays by unit as a preset choice does, written whole or with `by` over a default that splits")
    func playsSplitChoiceByUnit() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence",
              "theme": { "defaults": { "animation": { "title": { "subtitle": { "entrance": "frames/pop", "exit": "frames/fade" } } } } },
              "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ],
              "clips": [
                { "at": [0, 1], "kind": "title", "text": "a", "style": "headline", "animation": { "entrance": "frames/pop", "exit": "frames/fade", "by": "character", "stagger": 0.1 } },
                { "at": [0, 1], "kind": "title", "text": "b", "style": "headline", "animation": { "entrance": "frames/pop", "exit": "none", "by": "word" } },
                { "at": [0, 1], "kind": "title", "text": "c", "style": "subtitle", "animation": { "by": "line" } },
                { "at": [0, 1], "kind": "title", "text": "d", "style": "headline", "animation": { "entrance": "frames/pop", "exit": "frames/fade" } }
              ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips.map(\.animation.entrance?.preset) == ["frames/pop", "frames/pop", "frames/pop", "frames/pop"])
        #expect(plan.clips.map(\.animation.exit?.preset) == ["frames/fade", nil, "frames/fade", "frames/fade"])
        #expect(plan.clips.map(\.animation.units) == [
            UnitStagger(by: .character, stagger: 0.1),
            UnitStagger(by: .word, stagger: 0.12),
            UnitStagger(by: .line, stagger: 0.3),
            nil
        ])
    }

    @Test("`order` beside `by` reaches the plan in both object forms, and a choice that leaves it out plays in reading order")
    func ordersUnits() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [
              { "at": [0, 1], "kind": "title", "text": "a", "style": "headline", "animation": { "preset": "frames/fade", "by": "word", "order": "center" } },
              { "at": [0, 1], "kind": "title", "text": "b", "style": "headline", "animation": { "entrance": "frames/pop", "exit": "frames/fade", "by": "line", "stagger": 0.2, "order": "random" } },
              { "at": [0, 1], "kind": "title", "text": "c", "style": "headline", "animation": { "preset": "frames/fade", "by": "character" } }
            ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips.map(\.animation.units) == [
            UnitStagger(by: .word, stagger: 0.12, order: .center),
            UnitStagger(by: .line, stagger: 0.2, order: .random),
            UnitStagger(by: .character, stagger: 0.04, order: .forward)
        ])
    }

    @Test("`{\"order\": \"backward\"}` merges over a theme default that has `by` as `{\"by\": ...}` does, keeping its preset, unit and stagger")
    func mergesOrderOverDefault() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence",
              "theme": { "defaults": { "animation": { "title": {
                "subtitle": { "preset": "frames/pop", "by": "word", "stagger": 0.2 },
                "title": { "entrance": "frames/pop", "exit": "frames/fade", "by": "character", "order": "edges" } } } } },
              "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ],
              "clips": [
                { "at": [0, 1], "kind": "title", "text": "a", "style": "subtitle", "animation": { "order": "backward" } },
                { "at": [0, 1], "kind": "title", "text": "b", "style": "title", "animation": { "order": "backward" } },
                { "at": [0, 1], "kind": "title", "text": "c", "style": "title" }
              ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips.map(\.animation.entrance?.preset) == ["frames/pop", "frames/pop", "frames/pop"])
        #expect(plan.clips.map(\.animation.exit?.preset) == [nil, "frames/fade", "frames/fade"])
        #expect(plan.clips.map(\.animation.units) == [
            UnitStagger(by: .word, stagger: 0.2, order: .backward),
            UnitStagger(by: .character, stagger: 0.04, order: .backward),
            UnitStagger(by: .character, stagger: 0.04, order: .edges)
        ])
    }

    @Test(
        "`by` on a clip that is not a title, `stagger` or `order` without `by` and `by` over a preset with neither an entrance nor an exit stop",
        arguments: [
            (
                #"{ "at": [0, 1], "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "animation": { "preset": "frames/fade", "by": "word" } }"#,
                "clips[0].animation (rect): `by` plays a title's animation by unit, and this clip is not a title"
            ),
            (
                #"{ "at": [0, 1], "kind": "title", "text": "a", "style": "headline", "animation": { "preset": "frames/fade", "stagger": 0.1 } }"#,
                "clips[0].animation (title): `stagger` spaces a title's units, and the choice names no unit with `by`"
            ),
            (
                #"{ "at": [0, 1], "kind": "title", "text": "a", "style": "headline", "animation": { "preset": "frames/fade", "order": "center" } }"#,
                "clips[0].animation (title): `order` orders a title's units, and the choice names no unit with `by`"
            ),
            (
                #"{ "at": [0, 1], "kind": "title", "text": "a", "style": "headline", "animation": { "entrance": "frames/fade", "exit": "frames/fade", "order": "backward" } }"#,
                "clips[0].animation (title): `order` orders a title's units, and the choice names no unit with `by`"
            ),
            (
                #"{ "at": [0, 1], "kind": "title", "text": "a", "style": "headline", "animation": { "preset": "frames/none", "by": "word" } }"#,
                "clips[0].animation (title): `by` plays the entrance and the exit by unit, and the choice has neither"
            ),
            (
                #"{ "at": [0, 1], "kind": "rect", "stroke": { "width": 8 }, "area": [0, 0, 10, 10], "animation": { "entrance": "frames/fade", "exit": "none", "by": "word" } }"#,
                "clips[0].animation (rect): `by` plays a title's animation by unit, and this clip is not a title"
            ),
            (
                #"{ "at": [0, 1], "kind": "title", "text": "a", "style": "headline", "animation": { "entrance": "frames/fade", "exit": "frames/fade", "stagger": 0.1 } }"#,
                "clips[0].animation (title): `stagger` spaces a title's units, and the choice names no unit with `by`"
            ),
            (
                #"{ "at": [0, 1], "kind": "title", "text": "a", "style": "headline", "animation": { "entrance": "none", "exit": "none", "by": "word" } }"#,
                "clips[0].animation (title): `by` plays the entrance and the exit by unit, and the choice has neither"
            )
        ]
    )
    func refusesUnits(
        clip: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [ \#(clip) ] }
            """#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error?.description == message)
    }

    @Test("a theme default with `order` and no `by` stops at the title that takes it, as one with `stagger` does")
    func refusesDefaultOrderWithoutBy() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence",
              "theme": { "defaults": { "animation": { "title": { "subtitle": { "preset": "frames/fade", "order": "center" } } } } },
              "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ],
              "clips": [ { "at": [0, 1], "kind": "title", "text": "a", "style": "subtitle" } ] }
            """#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error?.description == "clips[0] (title): `order` orders a title's units, and the choice names no unit with `by`")
    }

    @Test("an animation preset that is not there stops")
    func refusesUnknownAnimation() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [
              { "at": [0, 1], "kind": "title", "text": "a", "style": "headline", "animation": { "entrance": "frames/pop", "exit": "mine/spin" } }
            ] }
            """#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error?.description == #"clips[0] (title): unknown animation preset "mine/spin". The pack "mine" holds the animation presets mine/wipe-in"#)
    }

    @Test(
        "a default animation naming a preset that is not there stops at its place in the theme, even when no clip takes it",
        arguments: [
            (
                #"{ "animation": { "shape": "mine/spin" } }"#,
                #"theme.defaults.animation.shape (animation defaults): unknown animation preset "mine/spin". The pack "mine" holds the animation presets mine/wipe-in"#
            ),
            (
                #"{ "animation": { "title": { "subtitle": "mine/spin" } } }"#,
                #"theme.defaults.animation.title.subtitle (title animations): unknown animation preset "mine/spin". The pack "mine" holds the animation presets mine/wipe-in"#
            )
        ]
    )
    func refusesUnknownDefaultAnimation(
        defaults: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "theme": { "defaults": \#(defaults) }, "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }
            """#)

        // When, Then
        let error = #expect(throws: ThemeError.self) { try sut.plan(document: document) }
        #expect(error?.description == message)
    }
}

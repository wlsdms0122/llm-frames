//
//  DefaultChoiceTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// A clip's preset choice merges over the theme's default for it. `frames/flash` lasts 0.5 seconds and
// `frames/wipe-right` 1, `frames/pulse` has a loop and `frames/pop` none, and `frames/warm` is a filter of no
// operations.
@Suite("DefaultChoice Tests")
struct DefaultChoiceTests {
    // MARK: - Property
    private let sut = Fixture.planner

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a transition without a preset changes the theme's default, and follows a change of it",
        arguments: [
            (#"{ "preset": "frames/wipe-right", "seconds": 0.25 }"#, "frames/wipe-right"),
            (#""frames/flash""#, "frames/flash")
        ]
    )
    func mergesTransitionOverDefault(
        defaults: String,
        preset: String
    ) throws {
        // When
        let plan = try sut.plan(document: transition(#"{ "seconds": 1 }"#, defaults: defaults))

        // Then
        #expect(plan.storyline[1].transition?.preset == preset)
        #expect(plan.storyline[1].transition?.seconds == 1)
    }

    @Test(
        "a transition that names a preset replaces the default whole, its seconds included, also where it names the default's own preset",
        arguments: [
            (#""frames/wipe-right""#, #"{ "preset": "frames/flash", "seconds": 0.25 }"#),
            (#"{ "preset": "frames/wipe-right", "args": {} }"#, #"{ "preset": "frames/wipe-right", "seconds": 0.25 }"#)
        ]
    )
    func replacesDefaultWithPreset(
        choice: String,
        defaults: String
    ) throws {
        // When
        let plan = try sut.plan(document: transition(choice, defaults: defaults))

        // Then
        #expect(plan.storyline[1].transition?.preset == "frames/wipe-right")
        #expect(plan.storyline[1].transition?.seconds == 1)
    }

    @Test("an animation without a preset plays the default of its kind with its arguments")
    func mergesAnimationOverDefault() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "theme": { "defaults": { "animation": { "shape": "frames/pulse" } } },
              "storyline": [ { "kind": "solid", "color": "#000000", "duration": 3 } ],
              "clips": [ { "kind": "rect", "area": [0, 0, 10, 10], "fill": "#FFFFFF", "at": [0, 3], "animation": { "args": {} } } ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips[0].animation.loop?.preset == "frames/pulse")
    }

    @Test(
        "a choice without a preset over a default of none, or on a clip that takes no default, stops",
        arguments: [
            (
                #"{ "seconds": 1 }"#,
                "storyline[1].transition (solid): a choice without a preset changes the theme's default, which is none here (theme.defaults.transition)"
            )
        ]
    )
    func refusesPartialTransitionOverNone(
        choice: String,
        message: String
    ) throws {
        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: transition(choice, defaults: #""cut""#)) }
        #expect(error.map { "\($0)" } == message)
    }

    @Test(
        "a filter without a preset, its arguments or its mix, stops over a default list, over none, and on an adjustment",
        arguments: [
            (
                #"{ "kind": "media", "media": "/abs/card.png", "at": [0, 1], "filter": { "kind": "preset", "args": {} } }"#,
                #"["frames/warm", "frames/warm"]"#,
                "clips[0].filter (image): a choice without a preset over the theme's default list (theme.defaults.filter), where which entry it changes is ambiguous"
            ),
            (
                #"{ "kind": "media", "media": "/abs/card.png", "at": [0, 1], "filter": { "kind": "preset", "args": {} } }"#,
                #""none""#,
                "clips[0].filter (image): a choice without a preset changes the theme's default, which is none here (theme.defaults.filter)"
            ),
            (
                #"{ "kind": "media", "media": "/abs/card.png", "at": [0, 1], "filter": { "kind": "preset", "mix": 0.5 } }"#,
                #"["frames/warm", "frames/warm"]"#,
                "clips[0].filter (image): a choice without a preset over the theme's default list (theme.defaults.filter), where which entry it changes is ambiguous"
            ),
            (
                #"{ "kind": "media", "media": "/abs/card.png", "at": [0, 1], "filter": { "kind": "preset", "mix": 0.5 } }"#,
                #""none""#,
                "clips[0].filter (image): a choice without a preset changes the theme's default, which is none here (theme.defaults.filter)"
            ),
            (
                #"{ "kind": "adjustment", "adjust": { "kind": "preset", "args": {} }, "at": [0, 1] }"#,
                #""frames/warm""#,
                "clips[0].adjust (adjustment): a choice without a preset changes the theme's default, and this clip takes none"
            ),
            (
                #"{ "kind": "media", "media": "/abs/card.png", "at": [0, 1], "filter": { "kind": "preset", "mix": 0.5 } }"#,
                #"{ "kind": "blur", "radius": 4 }"#,
                #"clips[0].filter (image): a preset entry without a preset changes the theme's default preset entry, and the default (theme.defaults.filter) is of kind "blur""#
            )
        ]
    )
    func refusesPartialFilter(
        clip: String,
        defaults: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "theme": { "defaults": { "filter": \#(defaults) } },
              "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 3 } ], "clips": [ \#(clip) ] }
            """#)

        // When, Then
        let error = #expect(throws: ResolveError.self) {
            try Fixture.sequencePlanner.plan(Fixture.planner.plan(document: document))
        }
        #expect(error.map { "\($0)" } == message)
    }

    @Test("a filter without a preset over a default of one preset is that preset")
    func mergesFilterOverDefault() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "theme": { "defaults": { "filter": "frames/warm" } },
              "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": { "kind": "preset", "args": {} } } ] }
            """#)

        // When
        let plan = try Fixture.sequencePlanner.plan(Fixture.planner.plan(document: document))

        // Then
        #expect(plan.storyline[0].filter.filter() == [FilterEntry(operations: [])])
    }

    @Test(
        "a filter op over a default op of its own kind merges over it key by key, and an op of another kind replaces it",
        arguments: [
            (#"{ "kind": "sepia", "mix": 0.5 }"#, FilterEntry(operations: [.sepia(amount: 0.8)], mix: 0.5)),
            (#"{ "kind": "contrast", "amount": 1.2 }"#, FilterEntry(operations: [.contrast(amount: 1.2)]))
        ]
    )
    func mergesFilterOperationOverDefault(
        choice: String,
        entry: FilterEntry
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "theme": { "defaults": { "filter": { "kind": "sepia", "amount": 0.8 } } },
              "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": \#(choice) } ] }
            """#)

        // When
        let plan = try Fixture.sequencePlanner.plan(Fixture.planner.plan(document: document))

        // Then
        #expect(plan.storyline[0].filter.filter() == [entry])
    }

    // MARK: - Private
    private func transition(
        _ choice: String,
        defaults: String
    ) throws -> JSONValue {
        try Fixture.json(#"""
            { "kind": "sequence", "theme": { "defaults": { "transition": \#(defaults) } },
              "storyline": [ { "kind": "solid", "color": "#000000", "duration": 3 }, { "kind": "solid", "color": "#FFFFFF", "duration": 3, "transition": \#(choice) } ] }
            """#)
    }
}

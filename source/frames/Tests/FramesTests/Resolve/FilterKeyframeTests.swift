//
//  FilterKeyframeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// The theme's default filter is `grade`. `soften` blurs by its `blur` argument, a theme length, `vignette` darkens to
// its `soft` argument, a radius within 0 to 1, and `fade` lifts black and lowers white by its `black` and `white`
// arguments, the elements of a `levels` input. The output is 1080 wide, so a theme length is scaled by 1080 / 1920.
@Suite("FilterKeyframe Tests")
struct FilterKeyframeTests {
    // MARK: - Property
    private let scale = 1080.0 / 1920
    private let grade: [ResolvedFilterOperation] = [.saturation(amount: 1.25), .blur(radius: 4 * (1080.0 / 1920))]
    private let presets = PresetTable(
        transitions: Fixture.presets.transitions,
        animations: Fixture.presets.animations,
        filters: Fixture.presets.filters.merging([
            "soften": #"""
                { "description": "", "params": { "blur": { "type": "number", "default": 4, "description": "the blur" } },
                  "ops": [ { "op": "blur", "radius": { "param": "blur" } } ] }
                """#,
            "vignette": #"""
                { "description": "", "params": { "soft": { "type": "number", "default": 0.5, "description": "the soft" } },
                  "ops": [ { "op": "vignette", "amount": 1, "radius": { "param": "soft" } } ] }
                """#,
            "fade": #"""
                { "description": "",
                  "params": { "black": { "type": "number", "default": 0, "description": "the black" },
                              "white": { "type": "number", "default": 1, "description": "the white" } },
                  "ops": [ { "op": "levels", "input": [ { "param": "black" }, { "param": "white" } ], "output": [0, 1] } ] }
                """#
        ]) { $1 }
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "mix keyframes fade the theme's default in, and follow a change of it",
        arguments: [(#""mine/grade""#, true), (#""frames/warm""#, false)]
    )
    func fadesDefaultIn(
        defaults: String,
        isGrade: Bool
    ) throws {
        // Given
        let clip = #"""
            { "media": "/abs/run.mp4", "in": 0, "out": 3,
              "keyframes": [ { "at": 0, "filter": { "mix": 0 } }, { "at": 2, "filter": { "mix": 1 } } ] }
            """#

        // When
        let plan = try plan(clip, defaults: defaults)

        // Then
        let operations = isGrade ? grade : []
        #expect(plan.storyline[0].filter.filter(at: 0) == [FilterEntry(operations: operations, mix: 0)])
        #expect(plan.storyline[0].filter.filter(at: 1) == [FilterEntry(operations: operations, mix: 0.5)])
        #expect(plan.storyline[0].filter.filter(at: 3) == [FilterEntry(operations: operations, mix: 1)])
    }

    @Test("a mix written alone over a default of one preset is that preset at that mix")
    func mixesDefault() throws {
        // When
        let plan = try plan(#"{ "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": { "mix": 0.5 } }"#)

        // Then
        #expect(plan.storyline[0].filter.filter() == [FilterEntry(operations: grade, mix: 0.5)])
    }

    @Test("an op written in place is an entry of its own, at its mix")
    func appliesOperationInPlace() throws {
        // When
        let plan = try plan(#"""
            { "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": [ "mine/grade", { "op": "exposure", "ev": 1, "mix": 0.5 } ] }
            """#)

        // Then
        #expect(plan.storyline[0].filter.filter() == [
            FilterEntry(operations: grade),
            FilterEntry(operations: [.exposure(ev: 1)], mix: 0.5)
        ])
    }

    @Test("an op parameter in place takes keyframes, a null one the written value, its length scaled")
    func movesOperationInPlace() throws {
        // When
        let plan = try plan(#"""
            { "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": { "op": "blur", "radius": 8 },
              "keyframes": [ { "at": 0, "filter": { "radius": 0 } }, { "at": 2, "filter": { "radius": null } } ] }
            """#)

        // Then
        #expect(plan.storyline[0].filter.filter(at: 1) == [FilterEntry(operations: [.blur(radius: 4 * scale)])])
        #expect(plan.storyline[0].filter.filter(at: 2) == [FilterEntry(operations: [.blur(radius: 8 * scale)])])
    }

    @Test("a keyframed preset argument moves the op parameter it fills, a length from 0 and scaled, with its ease")
    func movesPresetArgument() throws {
        // When
        let plan = try plan(#"""
            { "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": "soften",
              "keyframes": [ { "at": 0, "filter": { "args": { "blur": 0 } }, "ease": "ease-in" },
                             { "at": 2, "filter": { "args": { "blur": 8 } } } ] }
            """#)

        // Then
        let radius = try #require(operation(of: plan.storyline[0].filter)?["radius"])
        #expect(radius == .track([
            Keyframe(at: 0, value: .number(0), ease: .easeIn),
            Keyframe(at: 2, value: .number(8 * scale))
        ]))
        #expect(plan.storyline[0].filter.filter(at: 2) == [FilterEntry(operations: [.blur(radius: 8 * scale)])])
    }

    @Test("a list parameter whose elements arguments fill is timed element by element, each with its own keyframes")
    func movesListElementsApart() throws {
        // When
        let plan = try plan(#"""
            { "media": "/abs/run.mp4", "in": 0, "out": 4, "filter": "fade",
              "keyframes": [ { "at": 0, "filter": { "args": { "black": 0 } }, "ease": "ease-in" },
                             { "at": 1, "filter": { "args": { "white": 1 } } },
                             { "at": 2, "filter": { "args": { "black": 0.2 } } },
                             { "at": 3, "filter": { "args": { "white": 0.8 } } } ] }
            """#)

        // Then
        let input = try #require(operation(of: plan.storyline[0].filter)?["input"])
        #expect(input == .list([
            .track([Keyframe(at: 0, value: .number(0), ease: .easeIn), Keyframe(at: 2, value: .number(0.2))]),
            .track([Keyframe(at: 1, value: .number(1)), Keyframe(at: 3, value: .number(0.8))])
        ]))
        #expect(plan.storyline[0].filter.filter(at: 3) == [
            FilterEntry(operations: [.levels(input: [0.2, 0.8], output: [0, 1])])
        ])
    }

    @Test(
        "a keyframe's preset argument is checked against the ranges of the op parameters it fills, naming the keyframe",
        arguments: [
            (
                #"[ { "at": 0, "filter": { "args": { "soft": 0.5 } } }, { "at": 2, "filter": { "args": { "soft": 1.5 } } } ]"#,
                "vignette",
                "storyline[0].keyframes[1].filter (filter choice): its arguments give \"vignette\" a value it does not take: vignette: ops[0].radius (vignette): 1.5 is not within 0 to 1"
            ),
            (
                #"[ { "at": 0, "filter": { "args": { "blur": 0 } } } ]"#,
                "soften",
                "storyline[0].keyframes[0].filter (filter choice): its arguments give \"soften\" a value it does not take: soften: ops[0].radius (blur): 0 is not above 0"
            )
        ]
    )
    func refusesKeyframedArgumentOutOfRange(
        keyframes: String,
        preset: String,
        message: String
    ) throws {
        // Given
        let clip = #"{ "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": "\#(preset)", "keyframes": \#(keyframes) }"#

        // When, Then
        let error = #expect(throws: (any Error).self) { try plan(clip) }
        #expect(error.map { "\($0)" } == message)
    }

    @Test(
        "a keyframe that writes a preset, an op, a LUT, none or a list of another length stops",
        arguments: [
            (#""mine/grade""#, #""soften""#, "storyline[0].filter (keyframe): a name, a boolean or a form is static and is written on the clip, not in a keyframe"),
            (#""mine/grade""#, #"{ "op": "blur", "radius": 2 }"#, "storyline[0].filter (keyframe): a name, a boolean or a form is static and is written on the clip, not in a keyframe"),
            (
                #"{ "op": "lut", "file": "/abs/look.cube", "amount": 1 }"#,
                #"{ "file": "/abs/other.cube" }"#,
                "storyline[0].filter.file (keyframe): a name, a boolean or a form is static and is written on the clip, not in a keyframe"
            ),
            (
                #""mine/grade""#,
                #""none""#,
                #"storyline[0].filter (keyframe): false or "none" turns a value off and is written on the clip, not in a keyframe"#
            ),
            (#"["mine/grade", "frames/warm"]"#, #"[ { "mix": 0 } ]"#, "storyline[0].filter (keyframe): lists of different lengths: 2, 1")
        ]
    )
    func refusesStaticKeyframe(
        filter: String,
        keyframe: String,
        message: String
    ) throws {
        // Given
        let clip = #"""
            { "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": \#(filter),
              "keyframes": [ { "at": 1, "filter": \#(keyframe) } ] }
            """#

        // When, Then
        let error = #expect(throws: (any Error).self) { try plan(clip) }
        #expect(error.map { "\($0)" } == message)
    }

    // MARK: - Private
    private func plan(
        _ storylineClip: String,
        defaults: String = #""mine/grade""#
    ) throws -> SequencePlan {
        let document = try Fixture.json(#"""
            { "kind": "sequence", "theme": { "defaults": { "filter": \#(defaults) } }, "storyline": [ \#(storylineClip) ] }
            """#)
        let planner = TimePlanner(mediaFacts: Fixture.mediaFacts, presets: presets, library: Fixture.library)
        let sut = SequencePlanner(
            ocr: Fixture.ocr,
            languages: nil,
            tracker: Fixture.tracker,
            shaper: Fixture.shaper,
            presets: presets,
            library: Fixture.library
        )

        return try sut.plan(planner.plan(document: document))
    }

    // The body of the first op of a one-entry filter.
    private func operation(of filter: TimedValue) -> TimedValue? {
        guard case let .list(entries) = filter, case let .list(operations)? = entries.first?["ops"],
            case let .form(_, body)? = operations.first
        else {
            return nil
        }

        return body
    }
}

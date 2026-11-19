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
// arguments, the elements of a `levels` input. `crisp` blurs by its `blur` argument and pixelates by its `size`, both
// theme lengths, and `glow` blooms in its `tint` colour. The output is 1080 wide, so a theme length is scaled by 1080 / 1920.
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
                """#,
            "crisp": #"""
                { "description": "",
                  "params": { "blur": { "type": "number", "default": 4, "description": "the blur" },
                              "size": { "type": "number", "default": 8, "description": "the size" } },
                  "ops": [ { "op": "blur", "radius": { "param": "blur" } }, { "op": "pixelate", "size": { "param": "size" } } ] }
                """#,
            "glow": #"""
                { "description": "", "params": { "tint": { "type": "color", "default": "#FFFFFF", "description": "the tint" } },
                  "ops": [ { "op": "bloom", "amount": 1, "radius": 4, "color": { "param": "tint" } } ] }
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
        "a keyframe's preset arguments are checked by the preset's rules, argument by argument, naming the keyframe",
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
            ),
            (
                #"[ { "at": 0, "filter": { "args": { "blur": 0 } } }, { "at": 2, "filter": { "args": { "blur": 4, "size": 0 } } } ]"#,
                "crisp",
                "storyline[0].keyframes[1].filter (filter choice): its arguments give \"crisp\" a value it does not take: crisp: ops[1].size (pixelate): 0 is not above 0"
            ),
            (
                #"[ { "at": 0, "filter": { "args": { "tint": "nope" } } } ]"#,
                "glow",
                "storyline[0].keyframes[0].filter (video): the preset names the colour \"nope\", which is not in the theme's colors"
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
        "an op written in place is checked by a preset op's rules, statically and in each keyframe",
        arguments: [
            (
                #"{ "op": "levels", "input": [0.8, 0.2], "output": [0, 1] }"#,
                "[]",
                "storyline[0].filter.input (levels): [0.8, 0.2] is not within 0 to 1 with black below white"
            ),
            (
                #"{ "op": "levels", "input": [0, 1], "output": [0, 1] }"#,
                #"[ { "at": 1, "filter": { "input": [0.6, 0.4] } } ]"#,
                "storyline[0].keyframes[0].filter.input (levels): [0.6, 0.4] is not within 0 to 1 with black below white"
            ),
            (
                #"{ "op": "blur", "radius": 4 }"#,
                #"[ { "at": 1, "filter": { "radius": 0 } } ]"#,
                "storyline[0].keyframes[0].filter.radius (blur): 0 is not above 0"
            )
        ]
    )
    func refusesOperationInPlaceOutOfRange(
        filter: String,
        keyframes: String,
        message: String
    ) throws {
        // Given
        let clip = #"{ "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": \#(filter), "keyframes": \#(keyframes) }"#

        // When, Then
        let error = #expect(throws: (any Error).self) { try plan(clip) }
        #expect(error.map { "\($0)" } == message)
    }

    @Test("an op parameter only keyframes write passes the key tables and moves, its length scaled")
    func movesOperationParameterFromKeyframes() throws {
        // Given
        let clip = #"""
            { "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": { "op": "blur" },
              "keyframes": [ { "at": 0, "filter": { "radius": 0 } }, { "at": 2, "filter": { "radius": 8 } } ] }
            """#

        // When
        let plan = try plan(clip)

        // Then
        #expect(plan.storyline[0].filter.filter(at: 1) == [FilterEntry(operations: [.blur(radius: 4 * scale)])])
    }

    @Test(
        "an op parameter that neither the op, written on the clip or as the theme's default, nor its keyframes write stops",
        arguments: [
            (#""filter": { "op": "blur" },"#, #""mine/grade""#, "storyline[0].filter"),
            (#""filter": [ "mine/grade", { "op": "sharpen", "amount": 1 } ],"#, #""mine/grade""#, "storyline[0].filter[1]"),
            ("", #"{ "op": "blur" }"#, "storyline[0].filter")
        ]
    )
    func refusesMissingOperationParameter(
        filter: String,
        defaults: String,
        place: String
    ) throws {
        // Given
        let clip = #"{ "media": "/abs/run.mp4", "in": 0, "out": 3, \#(filter) "keyframes": [] }"#

        // When, Then
        let error = #expect(throws: ResolveError.self) { try plan(clip, defaults: defaults) }
        #expect(error.map { "\($0)" } == "\(place) (video): missing key \"radius\", which the clip does not write and no theme layer gives")
    }

    @Test("an in-place blur radius two keyframes write, one of them null, may be 0 at the other")
    func movesOperationInPlaceFromZero() throws {
        // Given
        let clip = #"""
            { "media": "/abs/run.mp4", "in": 0, "out": 3, "filter": { "op": "blur", "radius": 4 },
              "keyframes": [ { "at": 0, "filter": { "radius": 0 } }, { "at": 2, "filter": { "radius": null } } ] }
            """#

        // When
        let plan = try plan(clip)

        // Then
        #expect(plan.storyline[0].filter.filter(at: 1) == [FilterEntry(operations: [.blur(radius: 2 * scale)])])
    }

    @Test("a keyframe's stop over the theme's default names the clip, not the theme")
    func refusesKeyframeOverDefault() throws {
        // Given
        let clip = #"""
            { "media": "/abs/run.mp4", "in": 0, "out": 3, "keyframes": [ { "at": 0, "filter": { "args": { "tint": "nope" } } } ] }
            """#

        // When, Then
        let error = #expect(throws: (any Error).self) { try plan(clip, defaults: #""glow""#) }
        #expect(error.map { "\($0)" } == "storyline[0].keyframes[0].filter (video): the preset names the colour \"nope\", which is not in the theme's colors")
    }

    @Test(
        "a keyframe that writes a preset, an op, a LUT, none or a list of another length stops, naming the keyframe",
        arguments: [
            (#""mine/grade""#, #""soften""#, "storyline[0].keyframes[0].filter (keyframe): a name, a boolean or a form is static and is written on the clip, not in a keyframe"),
            (#""mine/grade""#, #"{ "op": "blur", "radius": 2 }"#, "storyline[0].keyframes[0].filter (keyframe): a name, a boolean or a form is static and is written on the clip, not in a keyframe"),
            (
                #"{ "op": "lut", "file": "/abs/look.cube", "amount": 1 }"#,
                #"{ "file": "/abs/other.cube" }"#,
                "storyline[0].keyframes[0].filter.file (keyframe): a name, a boolean or a form is static and is written on the clip, not in a keyframe"
            ),
            (
                #""mine/grade""#,
                #""none""#,
                #"storyline[0].keyframes[0].filter (keyframe): false or "none" turns a value off and is written on the clip, not in a keyframe"#
            ),
            (#"["mine/grade", "frames/warm"]"#, #"[ { "mix": 0 } ]"#, "storyline[0].keyframes[0].filter (keyframe): lists of different lengths: 2, 1")
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

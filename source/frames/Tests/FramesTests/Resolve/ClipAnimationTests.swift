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
    @Test("a parented clip without at takes no entrance and no exit, since it comes and goes with its picture")
    func dropsEntranceAndExitOfParentedClip() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "connected": [
              { "shape": "box", "area": "Send", "animation": "pulse" },
              { "at": [1, 2], "shape": "box", "area": "Send", "animation": "pulse" },
              { "title": "a", "style": "subtitle", "animation": "pulse" }
            ] } ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips[0].animation.entrance == nil)
        #expect(plan.clips[0].animation.loop?.preset == "pulse")
        #expect(plan.clips[0].animation.exit == nil)
        #expect(plan.clips[1].animation.entrance?.preset == "pulse")
        #expect(plan.clips[2].animation.exit?.preset == "pulse")
    }

    @Test("a clip that names no animation takes the theme's default for its kind, and a title the one for its style")
    func takesDefaultAnimation() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence",
              "theme": { "defaults": { "animation": { "title": { "subtitle": "pop" }, "shape": "draw", "media": "fade" } } },
              "storyline": [ { "media": "/abs/run.mp4" } ],
              "clips": [
                { "at": [0, 1], "title": "a", "style": "subtitle" },
                { "at": [0, 1], "title": "b", "style": "headline" },
                { "at": [0, 1], "shape": "box", "area": [0, 0, 10, 10] },
                { "at": [0, 1], "media": "/abs/log.png" },
                { "at": [0, 1], "media": "/abs/log.png", "animation": "none" },
                { "media": "/abs/bgm.m4a" }
              ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips.map { $0.animation.entrance?.preset } == ["pop", nil, "draw", "fade", nil, nil])
        #expect(plan.clips[5].animation == .none)
    }

    @Test("a shape's label takes its labelAnimation, else the label entry of the title defaults, and none takes none")
    func choosesLabelAnimation() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [
              { "at": [0, 1], "shape": "box", "area": [0, 0, 10, 10], "label": "a", "labelAnimation": "fade" },
              { "at": [0, 1], "shape": "box", "area": [0, 0, 10, 10], "label": "a" },
              { "at": [0, 1], "shape": "box", "area": [0, 0, 10, 10], "label": "a", "labelAnimation": "none" },
              { "at": [0, 1], "shape": "box", "area": [0, 0, 10, 10], "label": "a", "animation": "draw" }
            ] }
            """#)
        let themed = try Fixture.json(#"""
            { "kind": "sequence", "theme": { "defaults": { "animation": { "title": { "label": "stamp" } } } },
              "storyline": [ { "media": "/abs/run.mp4" } ],
              "clips": [ { "at": [0, 1], "shape": "box", "area": [0, 0, 10, 10], "label": "a" } ] }
            """#)

        // When
        let plan = try sut.plan(document: document)
        let themedPlan = try sut.plan(document: themed)

        // Then
        #expect(plan.clips.map { $0.labelAnimation.entrance?.preset } == ["fade", "pop", nil, "pop"])
        #expect(plan.clips[0].labelAnimation.exit?.preset == "fade")
        #expect(plan.clips[2].labelAnimation == .none)
        #expect(plan.clips[3].animation.entrance?.preset == "draw")
        #expect(themedPlan.clips[0].labelAnimation.entrance?.preset == "stamp")
    }

    @Test("a shape without a label takes no label animation")
    func takesNoLabelAnimationWithoutLabel() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [
              { "at": [0, 1], "shape": "box", "area": [0, 0, 10, 10] }
            ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips[0].labelAnimation == .none)
    }

    @Test("{entrance, exit} takes the entrance from one preset and the exit from another, and none on a side leaves it out")
    func splitsAnimationChoice() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [
              { "at": [0, 1], "media": "/abs/log.png", "animation": { "entrance": "pop", "exit": "fade" } },
              { "at": [0, 1], "media": "/abs/log.png", "animation": { "entrance": "none", "exit": "pulse" } }
            ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips[0].animation.entrance?.preset == "pop")
        #expect(plan.clips[0].animation.exit?.preset == "fade")
        #expect(plan.clips[1].animation.entrance == nil)
        #expect(plan.clips[1].animation.loop == nil)
        #expect(plan.clips[1].animation.exit?.span.length == 0.25)
    }

    @Test("an animation preset that is not there stops")
    func refusesUnknownAnimation() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [
              { "at": [0, 1], "title": "a", "style": "headline", "animation": { "entrance": "pop", "exit": "spin" } }
            ] }
            """#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error?.description == #"clips[0] (title): unknown animation preset "spin""#)
    }

    @Test(
        "a default animation naming a preset that is not there stops at its place in the theme, even when no clip takes it",
        arguments: [
            (
                #"{ "animation": { "shape": "spin" } }"#,
                #"theme.defaults.animation.shape (animation defaults): unknown animation preset "spin""#
            ),
            (
                #"{ "animation": { "title": { "subtitle": "spin" } } }"#,
                #"theme.defaults.animation.title.subtitle (title animations): unknown animation preset "spin""#
            )
        ]
    )
    func refusesUnknownDefaultAnimation(
        defaults: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "theme": { "defaults": \#(defaults) }, "storyline": [ { "media": "/abs/run.mp4" } ] }
            """#)

        // When, Then
        let error = #expect(throws: ThemeError.self) { try sut.plan(document: document) }
        #expect(error?.description == message)
    }
}

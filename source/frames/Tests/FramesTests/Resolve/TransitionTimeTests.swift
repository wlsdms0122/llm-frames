//
//  TransitionTimeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("Transition Time Tests")
struct TransitionTimeTests {
    // MARK: - Property
    private let sut = Fixture.planner

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a transition lasts min(transition seconds, previous duration, next duration)",
        arguments: [
            (#""flash""#, 3.0, 2.5, 0.5),
            (#"{ "preset": "flash", "seconds": 2 }"#, 3.0, 2.5, 2.0),
            (#""long""#, 3.0, 2.5, 2.5),
            (#""long""#, 1.0, 2.5, 1.0)
        ]
    )
    func clampsTransitionLength(
        transition: String,
        previous: Double,
        next: Double,
        seconds: Double
    ) throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [
              { "solid": "#000000", "duration": \##(previous) },
              { "solid": "#FFFFFF", "duration": \##(next), "transition": \##(transition) }
            ] }
            """##)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.storyline[1].transition?.seconds == seconds)
    }

    @Test("a transition is centred on the edit point, and the drawn ranges run over it without changing the sequence length")
    func centresTransitionOnEditPoint() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [
              { "solid": "#000000", "duration": 3 },
              { "solid": "#FFFFFF", "duration": 2, "transition": { "preset": "wipe-right", "seconds": 1 } },
              { "solid": "#FF0000", "duration": 2, "transition": "flash" }
            ] }
            """##)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.storyline[1].transition?.range == TimeRange(start: 2.5, end: 3.5))
        #expect(plan.storyline.map(\.edit) == [TimeRange(start: 0, end: 3), TimeRange(start: 3, end: 5), TimeRange(start: 5, end: 7)])
        #expect(plan.storyline.map(\.drawn) == [TimeRange(start: 0, end: 3.5), TimeRange(start: 2.5, end: 5.25), TimeRange(start: 4.75, end: 7)])
        #expect(plan.duration == 7)
    }

    @Test("during a transition the clips play their handles, and where the media runs out its first or last frame holds")
    func playsHandles() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [
              { "media": "/abs/short.mp4", "in": 1, "out": 2 },
              { "media": "/abs/short.mp4", "transition": { "preset": "flash", "seconds": 1 } }
            ] }
            """#)
        let plan = try sut.plan(document: document)

        // When
        let outgoing = plan.storyline[0].mediaTime(atSequenceTime: 1.25)
        let incoming = plan.storyline[1].mediaTime(atSequenceTime: 0.75)
        let held = plan.storyline[1].mediaTime(atSequenceTime: 4.75)

        // Then
        #expect(plan.storyline[0].drawn == TimeRange(start: 0, end: 1.5))
        #expect(outgoing == 2.25)
        #expect(incoming == 0)
        #expect(held == 3)
    }

    @Test("a still or solid clip simply goes on in a handle")
    func continuesStillInHandle() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [
              { "media": "/abs/card.png", "duration": 2 },
              { "solid": "#000000", "duration": 2, "transition": { "preset": "flash", "seconds": 1 } }
            ] }
            """##)
        let plan = try sut.plan(document: document)

        // When
        let still = plan.storyline[0].mediaTime(atSequenceTime: 2.5)
        let solid = plan.storyline[1].mediaTime(atSequenceTime: 1.5)

        // Then
        #expect(still == 2.5)
        #expect(solid == -0.5)
    }

    @Test("a transition written on the first storyline clip stops, even a cut")
    func refusesTransitionOnFirstClip() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "transition": "cut" } ] }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error?.description.hasPrefix("storyline[0].transition (video): the first storyline clip has no transition") == true)
    }

    @Test("the theme's default transition brings in every clip but the first, and a cut turns it off")
    func appliesDefaultTransition() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "theme": { "defaults": { "transition": "push-up" } }, "storyline": [
              { "solid": "#000000", "duration": 2 },
              { "solid": "#FFFFFF", "duration": 2 },
              { "solid": "#FF0000", "duration": 2, "transition": "cut" }
            ] }
            """##)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.storyline[0].transition == nil)
        #expect(plan.storyline[1].transition?.preset == "push-up")
        #expect(plan.storyline[1].transition?.seconds == 0.5)
        #expect(plan.storyline[2].transition == nil)
    }

    @Test("the theme in effect where the document is written gives the default under the document's own theme")
    func takesThemeInEffect() throws {
        // Given
        let theme = try ThemeMerger().merge([Fixture.json(#"{ "defaults": { "transition": "flash" } }"#)])
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 2 }, { "solid": "#FFFFFF", "duration": 2 } ] }
            """##)

        // When
        let plan = try sut.plan(document: document, theme: theme)

        // Then
        #expect(plan.storyline[1].transition?.preset == "flash")
    }

    @Test(
        "a transition that cannot play stops",
        arguments: [
            (#""dissolve""#, #"storyline[1] (solid): unknown transition preset "dissolve""#),
            (#"{ "preset": "flash", "seconds": 0 }"#, "storyline[1].transition (solid): a transition lasts more than 0 seconds, found 0"),
            (#"{ "preset": "dissolve", "seconds": 1 }"#, #"storyline[1] (solid): unknown transition preset "dissolve""#)
        ]
    )
    func refusesBrokenTransition(
        transition: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [
              { "solid": "#000000", "duration": 2 }, { "solid": "#FFFFFF", "duration": 2, "transition": \##(transition) }
            ] }
            """##)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error?.description == message)
    }
}

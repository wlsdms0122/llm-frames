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
            (#""frames/flash""#, 3.0, 2.5, 0.5),
            (#"{ "preset": "frames/flash", "seconds": 2 }"#, 3.0, 2.5, 2.0),
            (#""mine/long""#, 3.0, 2.5, 2.5),
            (#""mine/long""#, 1.0, 2.5, 1.0)
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
              { "solid": "#FFFFFF", "duration": 2, "transition": { "preset": "frames/wipe-right", "seconds": 1 } },
              { "solid": "#FF0000", "duration": 2, "transition": "frames/flash" }
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
              { "media": "/abs/short.mp4", "transition": { "preset": "frames/flash", "seconds": 1 } }
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
              { "solid": "#000000", "duration": 2, "transition": { "preset": "frames/flash", "seconds": 1 } }
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

    @Test("a transition's cover and matte media are probed for their frames and length, and one not probed stops")
    func probesCoverAndMatte() throws {
        // Given
        let span = Span(ease: .linear, keys: [])
        let presets = PresetTable(
            transitions: [
                "stinger": TransitionPreset(
                    description: "",
                    seconds: 1,
                    over: .incoming,
                    audio: .constantPower,
                    incoming: nil,
                    outgoing: nil,
                    cover: Cover(source: .media("/abs/leak.mov"), span: span),
                    matte: Matte(media: "/abs/matte.png", softness: 0, isInverted: false, ease: .linear)
                ),
                "lost": TransitionPreset(
                    description: "",
                    seconds: 1,
                    over: .incoming,
                    audio: .constantPower,
                    incoming: nil,
                    outgoing: nil,
                    cover: nil,
                    matte: Matte(media: "/abs/lost.png", softness: 0, isInverted: false, ease: .linear)
                )
            ],
            animations: Fixture.presets.animations,
            filters: Fixture.presets.filters
        )
        let sut = TimePlanner(mediaFacts: Fixture.mediaFacts, presets: presets, library: Fixture.library)
        let document = { (transition: String) in
            try Fixture.json(#"""
                { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 2 },
                                                     { "solid": "#FFFFFF", "duration": 2, "transition": "\#(transition)" } ] }
                """#)
        }

        // When
        let plan = try sut.plan(document: document("stinger"))
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document("lost")) }

        // Then
        let transition = try #require(plan.storyline[1].transition)
        #expect(transition.coverMedia?.file.frameTimes == [0, 0.5, 1, 1.5])
        #expect(transition.coverMedia?.duration == 2)
        #expect(transition.matteMedia?.file.path == "/abs/matte.png")
        #expect(transition.matteMedia?.file.frameTimes == [])
        #expect(error?.description == #"storyline[1].transition (solid): media "/abs/lost.png" is not there"#)
    }

    @Test("a transition's cover and matte take a page of a PDF, a one-page PDF named as a file its page 1")
    func probesPageCoverAndMatte() throws {
        // Given
        let sut = TimePlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: presets(cover: .page("/abs/deck.pdf", page: 3), matte: ("/abs/logo.pdf", nil)),
            library: Fixture.library
        )

        // When
        let plan = try sut.plan(document: transitionDocument)

        // Then
        let transition = try #require(plan.storyline[1].transition)
        #expect(transition.coverMedia?.file == MediaFile(
            path: "/abs/deck.pdf",
            size: Size(width: 595.276, height: 841.89),
            colorReading: .formulas(.srgb),
            page: 3
        ))
        #expect(transition.matteMedia?.file.page == 1)
        #expect(transition.matteMedia?.file.size == Size(width: 200, height: 100))
    }

    @Test(
        "a cover or matte of a PDF of several pages named as a file, a page above the count, a page of no PDF and a PDF of no pages stop",
        arguments: [
            (
                CoverSource.media("/abs/deck.pdf"),
                #"storyline[1].transition (solid): media "/abs/deck.pdf" is a PDF of 12 pages, more than one picture, so a page of it is named as {"file", "page"}"#
            ),
            (
                .page("/abs/deck.pdf", page: 13),
                #"storyline[1].transition (solid): media "/abs/deck.pdf" has 12 pages, so it has no page 13"#
            ),
            (
                .page("/abs/card.png", page: 1),
                #"storyline[1].transition (solid): media "/abs/card.png" is not a PDF, so it has no pages"#
            ),
            (
                .media("/abs/empty.pdf"),
                #"storyline[1].transition (solid): media "/abs/empty.pdf" cannot be probed: it is a PDF of no pages"#
            )
        ]
    )
    func refusesPageCover(cover: CoverSource, message: String) {
        // Given
        let sut = TimePlanner(
            mediaFacts: Fixture.mediaFacts,
            presets: presets(cover: cover, matte: nil),
            library: Fixture.library
        )

        // When, Then
        let error = #expect(throws: ModelError.self) { try sut.plan(document: transitionDocument) }
        #expect(error?.description == message)
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
            { "kind": "sequence", "theme": { "defaults": { "transition": "frames/push-up" } }, "storyline": [
              { "solid": "#000000", "duration": 2 },
              { "solid": "#FFFFFF", "duration": 2 },
              { "solid": "#FF0000", "duration": 2, "transition": "cut" }
            ] }
            """##)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.storyline[0].transition == nil)
        #expect(plan.storyline[1].transition?.preset == "frames/push-up")
        #expect(plan.storyline[1].transition?.seconds == 0.5)
        #expect(plan.storyline[2].transition == nil)
    }

    @Test("the theme in effect where the document is written gives the default under the document's own theme")
    func takesThemeInEffect() throws {
        // Given
        let theme = try ThemeMerger().merge([ThemeLayer(value: Fixture.json(#"{ "defaults": { "transition": "frames/flash" } }"#), place: .root)])
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 2 }, { "solid": "#FFFFFF", "duration": 2 } ] }
            """##)

        // When
        let plan = try sut.plan(document: document, theme: theme)

        // Then
        #expect(plan.storyline[1].transition?.preset == "frames/flash")
    }

    @Test(
        "a transition that cannot play stops",
        arguments: [
            (#""dissolve""#, #"storyline[1] (solid): unknown transition preset "dissolve". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#),
            (#"{ "preset": "dissolve", "seconds": 1 }"#, #"storyline[1] (solid): unknown transition preset "dissolve". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#)
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

    @Test("a default transition naming a preset that is not there stops at its place in the theme, even when no clip takes it")
    func refusesUnknownDefaultTransition() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "theme": { "defaults": { "transition": "dissolve" } }, "storyline": [
              { "solid": "#000000", "duration": 2 }, { "solid": "#FFFFFF", "duration": 2, "transition": "cut" }
            ] }
            """##)

        // When, Then
        let error = #expect(throws: ThemeError.self) { try sut.plan(document: document) }
        #expect(error?.description == #"theme.defaults.transition (defaults): unknown transition preset "dissolve". A preset is named <pack>/<name>, and the ones frames ships are frames/<name>"#)
    }

    // MARK: - Private
    private var transitionDocument: JSONValue {
        get throws {
            try Fixture.json(#"""
                { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 2 },
                                                     { "solid": "#FFFFFF", "duration": 2, "transition": "stinger" } ] }
                """#)
        }
    }

    // A preset `stinger` with that cover and that matte file and page.
    private func presets(
        cover: CoverSource,
        matte: (String, Int?)?
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
                    cover: Cover(source: cover, span: Span(ease: .linear, keys: [])),
                    matte: matte.map { Matte(media: $0.0, page: $0.1, softness: 0, isInverted: false, ease: .linear) }
                )
            ],
            animations: Fixture.presets.animations,
            filters: Fixture.presets.filters
        )
    }
}

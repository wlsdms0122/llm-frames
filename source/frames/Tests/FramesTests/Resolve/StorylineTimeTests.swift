//
//  StorylineTimeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("Storyline Time Tests")
struct StorylineTimeTests {
    // MARK: - Property
    private let sut = Fixture.planner

    // MARK: - Initializer
    // MARK: - Test
    @Test("storyline clips play end to end from 0, and the sequence ends where the last one ends")
    func laysClipsEndToEnd() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [
              { "kind": "media", "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2 },
              { "kind": "media", "media": "/abs/card.png", "duration": 2.5 },
              { "kind": "solid", "color": "#000000", "duration": 1 }
            ] }
            """##)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.storyline.map(\.edit) == [
            TimeRange(start: 0, end: 3),
            TimeRange(start: 3, end: 5.5),
            TimeRange(start: 5.5, end: 6.5)
        ])
        #expect(plan.duration == 6.5)
    }

    @Test("a timed clip's clip range is [in, out) on its media, and a still's is [0, duration)")
    func readsClipRanges() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [
              { "kind": "media", "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2 },
              { "kind": "media", "media": "/abs/card.png", "duration": 2.5 }
            ] }
            """##)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.storyline[0].source.clipRange == TimeRange(start: 2, end: 8))
        #expect(plan.storyline[0].source.speed == 2)
        #expect(plan.storyline[1].source.clipRange == TimeRange(start: 0, end: 2.5))
        #expect(plan.storyline[1].source.speed == 1)
    }

    @Test("in defaults to the start of the media and out to its end, and an out past the end is trimmed to it")
    func defaultsAndTrimsEditPoints() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [
              { "kind": "media", "media": "/abs/short.mp4" },
              { "kind": "media", "media": "/abs/short.mp4", "in": 1, "out": 9 }
            ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.storyline[0].source.clipRange == TimeRange(start: 0, end: 4))
        #expect(plan.storyline[1].source.clipRange == TimeRange(start: 1, end: 4))
        #expect(plan.duration == 7)
    }

    @Test("clip time maps to sequence time on a straight line, the same line outside the clip")
    func mapsClipTimeToSequenceTime() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [
              { "kind": "media", "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2,
                "keyframes": [ { "at": 1, "crop": { "scale": 1 } }, { "at": 8, "crop": { "scale": 1.08 } } ] },
              { "kind": "media", "media": "/abs/card.png", "duration": 2.5,
                "keyframes": [ { "at": 1.5, "crop": { "scale": 1 } }, { "at": 2, "crop": { "scale": 2 } } ] }
            ] }
            """##)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.storyline[0].keyframes.map(\.at) == [-0.5, 3])
        #expect(plan.storyline[0].map.clipTime(atSequenceTime: 1.5) == 5)
        #expect(plan.storyline[1].keyframes.map(\.at) == [4.5, 5])
        #expect(plan.storyline[1].map.sequenceTime(ofClipTime: 0) == 3)
    }

    @Test("a frame at an edit point belongs to the clip that starts there")
    func givesEditPointToIncomingClip() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [ { "kind": "solid", "color": "#000000", "duration": 2 }, { "kind": "solid", "color": "#FFFFFF", "duration": 2 } ] }
            """##)
        let plan = try sut.plan(document: document)

        // When
        let atEditPoint = plan.storylineIndex(at: 2)
        let justBefore = plan.storylineIndex(at: 2.nextDown)
        let atEnd = plan.storylineIndex(at: 4)

        // Then
        #expect(atEditPoint == 1)
        #expect(justBefore == 0)
        #expect(atEnd == nil)
    }

    @Test("an image sequence lasts its frame count over its rate and plays like a video")
    func timesImageSequence() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": { "kind": "imageSequence", "directory": "/abs/frames", "fps": 4 }, "in": 1 } ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.storyline[0].source.kind == .media(.video))
        #expect(plan.storyline[0].source.clipRange == TimeRange(start: 1, end: 3))
        #expect(plan.storyline[0].mediaTime(atSequenceTime: 5) == 2.75)
    }

    @Test(
        "fps defaults to the first video's nominal rate rounded to a common rate, the lower on a tie, or 30",
        arguments: [
            (#"[ { "kind": "media", "media": "/abs/card.png", "duration": 1 }, { "kind": "media", "media": "/abs/run.mp4" } ]"#, "", 30.0),
            (#"[ { "kind": "media", "media": "/abs/light-leak.mov" }, { "kind": "media", "media": "/abs/run.mp4" } ]"#, "", 24.0),
            (#"[ { "kind": "media", "media": "/abs/card.png", "duration": 1 } ]"#, "", 30.0),
            (#"[ { "kind": "media", "media": "/abs/light-leak.mov" } ]"#, #""format": { "fps": 60 }, "#, 60.0),
            (#"[ { "kind": "media", "media": "/abs/halfway.mp4" } ]"#, "", 25.0)
        ]
    )
    func defaultsFrameRate(
        storyline: String,
        format: String,
        fps: Double
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", \#(format)"storyline": \#(storyline) }"#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.fps == fps)
    }

    @Test(
        "a storyline clip that cannot play stops",
        arguments: [
            (#"[ { "kind": "media", "media": "/abs/short.mp4", "in": 3, "out": 2 } ]"#, "storyline[0] (video): in 3 is not before out 2 of the media"),
            (#"[ { "kind": "media", "media": "/abs/short.mp4", "in": 5 } ]"#, "storyline[0] (video): in 5 is at or after the end of the media at 4"),
            (#"[ { "kind": "media", "media": "/abs/short.mp4", "in": -2, "out": -1 } ]"#, "storyline[0] (video): out -1 is at or before the start of the media"),
            (#"[ { "kind": "media", "media": "/abs/short.mp4", "speed": 0 } ]"#, "storyline[0].speed (video): speed must be above 0, found 0"),
            (#"[ { "kind": "media", "media": "/abs/card.png", "duration": 0 } ]"#, "storyline[0].duration (image): a still or solid clip needs a duration above 0, found 0"),
            (##"[ { "kind": "solid", "color": "#000000" } ]"##, #"storyline[0] (solid): missing key "duration""#),
            ("[]", "storyline (sequence): the storyline is empty, and a sequence needs at least one storyline clip")
        ]
    )
    func refusesUnplayableClip(
        storyline: String,
        message: String
    ) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": \#(storyline) }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error?.description == message)
    }

    @Test("an in before the start of the media is moved to it")
    func clampsInToMediaStart() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/short.mp4", "in": -1 } ] }"#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.storyline[0].source.clipRange == TimeRange(start: 0, end: 4))
    }

    @Test("a compound clip plays its nested sequence, whose duration is its media length")
    func timesCompoundClip() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [
              { "kind": "media", "media": { "kind": "sequence", "storyline": [ { "kind": "solid", "color": "#000000", "duration": 2 }, { "kind": "media", "media": "/abs/short.mp4" } ] }, "in": 1 }
            ] }
            """##)

        // When
        let plan = try sut.plan(document: document)

        // Then
        let nested = try #require(plan.storyline[0].source.media?.sequence)
        #expect(plan.storyline[0].source.kind == .media(.sequence))
        #expect(plan.storyline[0].source.clipRange == TimeRange(start: 1, end: 6))
        #expect(nested.storyline[1].place.description == "storyline[0].media.storyline[1]")
        #expect(plan.storyline[0].mediaTime(atSequenceTime: 9) < 6)
    }

    @Test("a document named by a path that is not there stops")
    func refusesMissingDocument() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/intro.json" } ] }"#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error == .unknownReference(place: Place(components: [.key("storyline"), .index(0, id: nil), .key("media")]), kind: .genericClip(.storyline), reference: UnknownReference(kind: .media, name: "/abs/intro.json", hint: nil)))
    }
}

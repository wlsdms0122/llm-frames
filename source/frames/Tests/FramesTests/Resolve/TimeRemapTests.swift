//
//  TimeRemapTests.swift
//  FramesTests
//
//  Created by JSilver on 11/18/26.
//

import Testing

@testable import Frames

@Suite("TimeRemap Tests")
struct TimeRemapTests {
    // MARK: - Property
    private let sut = Fixture.planner
    private let storylineClip = Place(components: [.key("storyline"), .index(0, id: nil)])
    private let sequenceClip = Place(components: [.key("clips"), .index(0, id: nil)])
    private let video = PlaceKind.clip(.media(.video))

    // MARK: - Initializer
    // MARK: - Test
    @Test("a static timeRemap stops, since it is written only in keyframes")
    func refusesStaticTimeRemap() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "timeRemap": 2 } ] }
            """#)
        let checker = KeyChecker(mediaKinds: MediaKindTable(["/abs/screen.mp4": .video], templates: []))

        // When, Then
        let error = #expect(throws: ModelError.self) { try checker.check(document: document) }
        #expect(error == .staticKeyframedOnly(
            place: storylineClip.appending(key: "timeRemap"),
            kind: "video",
            property: "timeRemap"
        ))
    }

    @Test("timeRemap beside speed stops")
    func refusesSpeed() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "speed": 2,
              "keyframes": [ { "at": 0, "timeRemap": 1 } ] } ] }
            """#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error == .speedWithTimeRemap(place: storylineClip.appending(key: "speed"), kind: video))
    }

    @Test(
        "a remapped clip plays no sound, so what shapes its sound stops",
        arguments: [#""volume": 0.5"#, #""pan": -0.5"#, #""fadeIn": 1"#, #""fadeOut": 1"#]
    )
    func refusesSound(key: String) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", \#(key),
              "keyframes": [ { "at": 0, "timeRemap": 1 } ] } ] }
            """#)
        let name = String(key.dropFirst().prefix { $0 != "\"" })

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error == .soundWithTimeRemap(place: storylineClip.appending(key: name), kind: video, key: name))
    }

    @Test(
        "a remapped media clip off the storyline takes no in, out or loop",
        arguments: [#""in": 1"#, #""out": 2"#, #""loop": false"#]
    )
    func refusesRange(key: String) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 4 } ],
              "clips": [ { "media": "/abs/screen.mp4", "at": [0, 2], \#(key),
                "keyframes": [ { "at": 0, "timeRemap": 1 } ] } ] }
            """#)
        let name = String(key.dropFirst().prefix { $0 != "\"" })

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error == .rangeWithTimeRemap(place: sequenceClip.appending(key: name), kind: video, key: name))
    }

    @Test("a remapped media clip off the storyline takes at as [start, end], not a single start")
    func refusesSingleStart() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 4 } ],
              "clips": [ { "media": "/abs/screen.mp4", "at": 1, "keyframes": [ { "at": 1, "timeRemap": 1 } ] } ] }
            """#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error == .singleStartWithTimeRemap(place: sequenceClip.appending(key: "at"), kind: video))
    }

    @Test("a remapped storyline clip has speed 1 and lasts out - in, its out past the end of its media kept")
    func keepsClipRangePastMedia() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "in": 1, "out": 6,
              "keyframes": [ { "at": 1, "timeRemap": 2 } ] } ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.storyline[0].source.clipRange == TimeRange(start: 1, end: 6))
        #expect(plan.storyline[0].source.speed == 1)
        #expect(plan.storyline[0].edit == TimeRange(start: 0, end: 5))
        #expect(plan.duration == 5)
    }

    @Test("keys before in and after out land in sequence time on the clip's line, their eases intact")
    func movesKeysToSequenceTime() throws {
        // Given
        // The clip starts at sequence time 2 with `in` 1, so clip time c is sequence time c + 1.
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 2 },
              { "media": "/abs/screen.mp4", "in": 1, "out": 3, "keyframes": [
                { "at": 0, "timeRemap": 0, "ease": "ease-in" }, { "at": 2, "timeRemap": 1, "ease": "back-out" },
                { "at": 4, "timeRemap": 3.5 } ] } ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        let remapped = plan.storyline[1]
        #expect(remapped.timeRemap == [
            Keyframe(at: 1, value: 0, ease: .easeIn),
            Keyframe(at: 3, value: 1, ease: .backOut),
            Keyframe(at: 5, value: 3.5)
        ])
        #expect(remapped.mediaTime(atSequenceTime: 2) == Ease.easeIn.value(at: 0.5))
        #expect(remapped.mediaTime(atSequenceTime: 4) == 1 + 2.5 * Ease.backOut.value(at: 0.5))
    }

    @Test("two keys with one value hold, a lower next value plays backwards and the last key holds after it")
    func holdsAndReverses() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "in": 0, "out": 4, "keyframes": [
              { "at": 0, "timeRemap": 1 }, { "at": 1, "timeRemap": 1 }, { "at": 2, "timeRemap": 0.5 } ] } ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        let times = [0, 0.5, 1, 1.5, 2, 3.5].map(plan.storyline[0].mediaTime(atSequenceTime:))
        #expect(times == [1, 1, 1, 0.75, 0.5, 0.5])
    }

    @Test("a value outside the media clamps to its first or last frame; a hold past the end shows the last")
    func clampsOutsideMedia() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "in": 0, "out": 4, "keyframes": [
              { "at": 0, "timeRemap": -1 }, { "at": 2, "timeRemap": 9 } ] } ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        let times = [0, 0.1, 2, 3.5].map(plan.storyline[0].mediaTime(atSequenceTime:))
        #expect(times == [0, 0, 3.9, 3.9])
    }

    @Test("a connected media clip's remap keys are on its storyline clip's clock and give its media time in its window")
    func remapsConnectedClip() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 2 },
              { "solid": "#000000", "duration": 4, "connected": [ { "media": "/abs/screen.mp4", "at": [0, 2],
                "keyframes": [ { "at": 0, "timeRemap": 3 }, { "at": 2, "timeRemap": 1 } ] } ] } ] }
            """#)

        // When
        let plan = try sut.plan(document: document)

        // Then
        #expect(plan.clips[0].timing == .remapped(
            origin: 2,
            timeRemap: [Keyframe(at: 2, value: 3), Keyframe(at: 4, value: 1)]
        ))
        #expect(plan.clips[0].window == TimeRange(start: 2, end: 4))
        #expect(plan.clips[0].mediaClock?.mediaTime(atSequenceTime: 3) == 2)
    }

    @Test("a remapped clip has no audio entry, on the storyline or off it")
    func playsNoSound() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 4,
              "keyframes": [ { "at": 0, "timeRemap": 1 } ] } ],
              "clips": [ { "media": "/abs/run.mp4", "at": [0, 2], "keyframes": [ { "at": 0, "timeRemap": 5 } ] },
                         { "media": "/abs/run.mp4", "at": [0, 2] } ] }
            """#)

        // When
        let sequence = try ResolvedSequence(plan: Fixture.documentPlanner.plan(document), hashes: FileHashTable())

        // Then
        #expect(sequence.audio.map(\.place) == ["clips[1]"])
    }

    @Test("the resolved document writes timeRemap in sequence time and a remapped media clip's in, out, loop as null")
    func writesTimeRemap() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/screen.mp4", "in": 1, "out": 3,
              "keyframes": [ { "at": 1, "timeRemap": 2, "ease": "ease-out" }, { "at": 3, "timeRemap": 0 } ] } ],
              "clips": [ { "media": "/abs/short.mp4", "at": [0, 2], "keyframes": [ { "at": 0, "timeRemap": 3 } ] } ] }
            """#)
        let sequence = try ResolvedSequence(plan: Fixture.documentPlanner.plan(document), hashes: FileHashTable())

        // When
        let text = ResolvedDocumentWriter().write(sequence)
        let read = try ResolvedDocumentReader().read(text)
        let json = try Fixture.object(text)

        // Then
        #expect(read == sequence)
        let storyline = try #require(json["storyline"]?.arrayValue?.first?.objectValue)
        let clip = try #require(json["clips"]?.arrayValue?.first?.objectValue)
        #expect(storyline["speed"] == .number(1))
        #expect(storyline["timeRemap"]?.arrayValue?.count == 2)
        #expect(storyline["timeRemap"]?.arrayValue?.first?.objectValue?["at"] == .number(0))
        #expect(storyline["timeRemap"]?.arrayValue?.first?.objectValue?["ease"] == .string("ease-out"))
        #expect(["in", "out", "loop"].map { clip[$0] } == [.null, .null, .null])
        #expect(clip["origin"] == .number(0))
        #expect(clip["speed"] == .number(1))
        #expect(clip["timeRemap"]?.arrayValue?.count == 1)
    }

    // MARK: - Private
}

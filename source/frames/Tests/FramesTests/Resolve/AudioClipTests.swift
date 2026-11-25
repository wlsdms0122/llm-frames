//
//  AudioClipTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// `/abs/run.mp4` (30 seconds) holds picture and sound, `/abs/short.mp4` only a picture, `/abs/card.png` is a still and
// `/abs/bgm.m4a` holds only sound.
@Suite("AudioClip Tests")
struct AudioClipTests {
    // MARK: - Property
    private let sut = Fixture.planner
    private let checker = KeyChecker(mediaKinds: MediaKindTable(
        ["/abs/run.mp4": .video, "/abs/card.png": .image, "/abs/bgm.m4a": .audio],
        templates: []
    ))
    private let clip = Place(components: [.key("clips"), .index(0, id: nil)])

    // MARK: - Initializer
    // MARK: - Test
    @Test("an audio clip of a video takes its sound alone, placed as an audio clip of a sound file is")
    func takesSoundAlone() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 6 } ],
              "clips": [ { "kind": "audio", "media": "/abs/run.mp4", "at": 1, "in": 2, "out": 4, "volume": 0.5 } ] }
            """#)

        // When
        try checker.check(document: document)
        let time = try sut.plan(document: document)
        let plan = try Fixture.sequencePlanner.plan(time)

        // Then
        #expect(time.clips[0].kind == .media(.audio))
        #expect(plan.sound.map(\.place.description) == ["storyline[0]", "clips[0]"])
        #expect(plan.sound[1].range == TimeRange(start: 1, end: 3))
        #expect(plan.sound[1].played.map == TimeMap(origin: 1, in: 2, speed: 1))
        #expect(plan.sound[1].volume == .value(0.5))
    }

    @Test("a media clip of a video shows its picture")
    func keepsPicture() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 6 } ],
              "clips": [ { "kind": "media", "media": "/abs/run.mp4", "at": 1, "out": 2 } ] }
            """#)

        // When
        try checker.check(document: document)
        let time = try sut.plan(document: document)

        // Then
        #expect(time.clips[0].kind == .media(.video))
    }

    @Test("an audio clip takes an audio clip's keys whatever its media is, so a key of a picture stops")
    func refusesPictureKey() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 6 } ],
              "clips": [ { "kind": "audio", "media": "/abs/run.mp4", "at": 0, "position": [0, 0] } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try checker.check(document: document) }
        guard case let .unknownKey(place, kind, key, _) = error else {
            Issue.record("expected an unknown key, got \(String(describing: error))")
            return
        }
        #expect(place == clip)
        #expect(kind == "audio")
        #expect(key == "position")
    }

    @Test("a storyline clip takes no kind audio, since a storyline clip is a picture")
    func refusesAudioOnStoryline() throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "audio", "media": "/abs/run.mp4" } ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try checker.check(document: document) }
        #expect(error?.description == #"storyline[0].kind (storyline clip): unknown value "audio". Allowed: media, solid"#)
    }

    @Test("an audio clip of a still stops, since a still has no sound")
    func refusesStill() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ],
              "clips": [ { "kind": "audio", "media": "/abs/card.png" } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try checker.check(document: document) }
        #expect(error == .misplacedMedia(
            place: clip.appending(key: "media"),
            kind: "audio",
            reason: "a still has no sound, and an audio clip takes its media's sound"
        ))
    }

    @Test("a media clip of a sound file stops, naming the kind of a clip of its sound alone")
    func refusesSoundAsMediaClip() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a" } ] }
            """#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try checker.check(document: document) }
        #expect(error?.description == #"clips[0].media (media): this media has no picture, and a media clip shows one. A clip of its sound alone is of kind "audio""#)
    }

    @Test("an audio clip of a sound file takes its sound")
    func takesSoundFile() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 6 } ],
              "clips": [ { "kind": "audio", "media": "/abs/bgm.m4a", "at": 1 } ] }
            """#)

        // When
        try checker.check(document: document)
        let time = try sut.plan(document: document)

        // Then
        #expect(time.clips[0].kind == .media(.audio))
    }

    @Test("an audio clip of a video without sound stops, since the clip would play nothing")
    func refusesSilentVideo() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 6 } ],
              "clips": [ { "kind": "audio", "media": "/abs/short.mp4", "at": 0 } ] }
            """#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error == .audioWithoutSound(place: clip.appending(key: "media"), kind: .clip(.media(.audio))))
    }
}

//
//  PictureOffTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Testing

@testable import Frames

// `/abs/run.mp4` (30 seconds) holds picture and sound, `/abs/short.mp4` only a picture.
@Suite("PictureOff Tests")
struct PictureOffTests {
    // MARK: - Property
    private let sut = Fixture.planner
    private let checker = KeyChecker(mediaKinds: MediaKindTable(
        ["/abs/run.mp4": .video, "/abs/card.png": .image, "/abs/bgm.m4a": .audio],
        templates: []
    ))
    private let clip = Place(components: [.key("clips"), .index(0, id: nil)])

    // MARK: - Initializer
    // MARK: - Test
    @Test("a video clip with \"picture\": false is an audio clip of its sound, placed as an audio clip is")
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

    @Test("a video clip with \"picture\": true keeps its picture")
    func keepsPicture() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 6 } ],
              "clips": [ { "kind": "media", "media": "/abs/run.mp4", "picture": true, "at": 1, "out": 2 } ] }
            """#)

        // When
        try checker.check(document: document)
        let time = try sut.plan(document: document)

        // Then
        #expect(time.clips[0].kind == .media(.video))
    }

    @Test("a clip of a video's sound takes an audio clip's keys, so a picture key stops")
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

    @Test(
        "picture stops on a storyline clip, an image and an audio file",
        arguments: [
            #"{ "kind": "sequence", "storyline": [ { "kind": "audio", "media": "/abs/run.mp4" } ] }"#,
            #"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [ { "kind": "audio", "media": "/abs/card.png" } ] }"#,
            #"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [ { "kind": "audio", "media": "/abs/bgm.m4a" } ] }"#
        ]
    )
    func refusesPictureWithoutSoundToKeep(document: String) throws {
        // Given
        let document = try Fixture.json(document)

        // When, Then
        let error = #expect(throws: ModelError.self) { try checker.check(document: document) }
        guard case let .unknownKey(_, _, key, _) = error else {
            Issue.record("expected an unknown key, got \(String(describing: error))")
            return
        }
        #expect(key == "picture")
    }

    @Test("\"picture\": false on a video without sound stops, since the clip would play nothing")
    func refusesSilentVideo() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 6 } ],
              "clips": [ { "kind": "audio", "media": "/abs/short.mp4", "at": 0 } ] }
            """#)

        // When, Then
        let error = #expect(throws: ResolveError.self) { try sut.plan(document: document) }
        #expect(error == .pictureOffWithoutSound(place: clip.appending(key: "picture"), kind: .clip(.media(.video))))
    }
}

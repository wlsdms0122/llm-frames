//
//  SplitEditTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import Testing

@testable import Frames

// `/abs/run.mp4` (30 seconds) holds picture and sound, `/abs/short.mp4` only a picture.
@Suite("SplitEdit Tests")
struct SplitEditTests {
    // MARK: - Property
    private let sut = Fixture.sequencePlanner
    private let checker = KeyChecker(mediaKinds: MediaKindTable(["/abs/run.mp4": .video, "/abs/page.png": .image], templates: []))
    private let second = Place(components: [.key("storyline"), .index(1, id: nil)])

    // MARK: - Initializer
    // MARK: - Test
    @Test("a split of 0 plays the sound a clip plays without one")
    func zeroSplitIsNoSplit() throws {
        // When
        let split = try plan(storyline(second: #""split": { "before": 0, "after": 0 }"#))
        let plain = try plan(storyline(second: nil))

        // Then
        #expect(split.sound == plain.sound)
    }

    @Test("a J cut starts a storyline clip's sound before its edit point, over its neighbour's, and fades in there")
    func movesStorylineEdge() throws {
        // When
        let plan = try plan(storyline(second: #""split": { "before": 1 }, "fadeIn": 0.5"#))

        // Then
        let first = try #require(plan.sound.first { $0.place == Place(components: [.key("storyline"), .index(0, id: nil)]) })
        let sound = try #require(plan.sound.first { $0.place == second })
        #expect(first.range == TimeRange(start: 0, end: 4))
        #expect(sound.range == TimeRange(start: 3, end: 8))
        #expect(sound.audible == sound.range)
        #expect(sound.fadeIn == TimeRange(start: 3, end: 3.5))
        #expect(sound.played.map.clipTime(atSequenceTime: 3) == 1)
    }

    @Test("a trim of the edit point moves the sound with it, the split kept")
    func keepsSplitOverTrim() throws {
        // When
        let plan = try plan(storyline(second: #""split": { "before": 1 }"#, secondIn: 3))

        // Then
        let sound = try #require(plan.sound.first { $0.place == second })
        #expect(sound.range == TimeRange(start: 3, end: 7))
        #expect(sound.played.map.clipTime(atSequenceTime: 3) == 2)
    }

    @Test("across a transition the clip's own side of the crossfade and its fade-in move with its edge, and the neighbour's stay")
    func movesOwnCrossfade() throws {
        // When
        let split = try plan(storyline(second: #""split": { "before": 0.25 }, "transition": "frames/wipe-right", "fadeIn": 0.5"#))
        let plain = try plan(storyline(second: #""transition": "frames/wipe-right", "fadeIn": 0.5"#))

        // Then
        let first = { (plan: SequencePlan) in plan.sound.first { $0.place == Place(components: [.key("storyline"), .index(0, id: nil)]) } }
        let sound = { (plan: SequencePlan) in plan.sound.first { $0.place == self.second } }
        let incoming = try #require(sound(plain)?.incoming)
        let moved = try #require(sound(split)?.incoming)
        #expect(moved.range == TimeRange(start: incoming.range.start - 0.25, end: incoming.range.end - 0.25))
        #expect(moved.curve == incoming.curve)
        #expect(sound(split)?.range.start == (sound(plain)?.range.start ?? 0) - 0.25)
        let fadeIn = try #require(sound(plain)?.fadeIn)
        #expect(sound(split)?.fadeIn == TimeRange(start: fadeIn.start - 0.25, end: fadeIn.end - 0.25))
        #expect(first(split)?.outgoing == first(plain)?.outgoing)
        #expect(first(split)?.range == first(plain)?.range)
        #expect(first(split)?.fadeOut == first(plain)?.fadeOut)
    }

    @Test("a J cut's overlap is mixed from both sounds, each segment over it at its own media time")
    func mixesOverlap() throws {
        // Given
        let plan = try plan(storyline(second: #""split": { "before": 1 }"#))

        // When
        let mix = MixPlanner().mix(of: try ResolvedSequence(plan: plan, hashes: FileHashTable()))

        // Then
        let overlapping = mix.segments.filter { $0.start < 4 && $0.end > 3 }
        #expect(overlapping.map { [$0.start, $0.end, $0.mediaStart] } == [[0, 4, 2], [3, 8, 1]])
    }

    @Test("a resolved split clip's sound starts and ends where its split moves its edges")
    func resolvesMovedEdges() throws {
        // Given
        let plan = try plan(storyline(second: #""split": { "before": 1, "after": 0.5 }"#))

        // When
        let resolved = try ResolvedSequence(plan: plan, hashes: FileHashTable())

        // Then
        let sound = try #require(resolved.audio.first { $0.place == second.description })
        #expect([sound.start, sound.end] == [3, 8.5])
        #expect(sound.audible == TimeRange(start: 3, end: 8.5))
    }

    @Test("a connected clip's split starts its sound before its picture, on its time map")
    func movesConnectedEdge() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 0, "out": 6, "connected": [
                { "media": "/abs/run.mp4", "at": [2, 4], "in": 5, "split": { "before": 1, "after": 0.5 } } ] } ] }
            """#)

        // Then
        let sound = try #require(plan.sound.first { $0.place.description == "storyline[0].connected[0]" })
        #expect(sound.range == TimeRange(start: 1, end: 4.5))
        #expect(sound.audible == sound.range)
        #expect(sound.played.map.clipTime(atSequenceTime: 1) == 4)
    }

    @Test(
        "a split stops on a clip without sound, past its media's sound and outside the sequence, naming the edge",
        arguments: [
            (#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 4, "connected": [ { "media": "/abs/short.mp4", "at": 1, "split": { "before": 0.5 } } ] } ] }"#,
             #"storyline[0].connected[0].split (video): this clip plays no sound, so a split has no sound to move"#),
            (#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 4 }, { "media": "/abs/run.mp4", "in": 0.5, "out": 4, "split": { "before": 1 } } ] }"#,
             #"storyline[1].split.before (video): the split moves the clip's sound past where its media holds sound"#),
            (#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 4 }, { "media": "/abs/run.mp4", "in": 26, "split": { "after": 1 } }, { "media": "/abs/run.mp4", "out": 4 } ] }"#,
             #"storyline[1].split.after (video): the split moves the clip's sound past where its media holds sound"#),
            (#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 4, "split": { "before": 1 } }, { "media": "/abs/run.mp4", "out": 4 } ] }"#,
             #"storyline[0].split.before (video): the split moves the clip's sound outside the sequence"#),
            (#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 4 }, { "media": "/abs/run.mp4", "out": 4, "split": { "after": 1 } } ] }"#,
             #"storyline[1].split.after (video): the split moves the clip's sound outside the sequence"#),
            (#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 4, "connected": [ { "media": "/abs/run.mp4", "in": 5, "at": [0.5, 2], "split": { "before": 1 } } ] } ] }"#,
             #"storyline[0].connected[0].split.before (video): the split moves the clip's sound outside the sequence"#),
            (#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 4 } ], "clips": [ { "media": "/abs/run.mp4", "at": [2, 4], "split": { "after": 1 } } ] }"#,
             #"clips[0].split.after (video): the split moves the clip's sound outside the sequence"#),
            (#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 4, "connected": [ { "media": "/abs/run.mp4", "at": [1, 3], "split": { "before": 0.5 }, "keyframes": [ { "at": 0, "timeRemap": 0 }, { "at": 1, "timeRemap": 1 } ] } ] } ] }"#,
             nil)
        ]
    )
    func refusesSplit(document: String, message: String?) throws {
        // When, Then
        let error = #expect(throws: (any Error).self) { try plan(document) }
        if let message {
            #expect(error.map { "\($0)" } == message)
        } else if case let .soundWithTimeRemap(_, _, key)? = error as? ResolveError {
            #expect(key == "split")
        } else {
            Issue.record("expected a remapped clip's sound key to stop, got \(String(describing: error))")
        }
    }

    @Test("the key tables take a split on storyline and visual media clips of a video, and refuse it on a still and an audio clip")
    func checksKeys() throws {
        // Given
        let accepted = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "split": { "before": 1, "after": 0 } } ],
              "clips": [ { "media": "/abs/run.mp4", "split": { "after": 0.5 } } ] }
            """#)
        let refused = [
            #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ { "media": "/abs/page.png", "split": { "before": 1 } } ] }"#,
            #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ { "media": "/abs/run.mp4", "picture": false, "split": { "before": 1 } } ] }"#,
            #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "split": { "before": -1 } } ] }"#,
            #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "split": { "lead": 1 } } ] }"#
        ]

        // When, Then
        try checker.check(document: accepted)
        for document in refused {
            #expect(throws: ModelError.self) { try checker.check(document: Fixture.json(document)) }
        }
    }

    // MARK: - Private
    @discardableResult
    private func plan(_ document: String) throws -> SequencePlan {
        try sut.plan(Fixture.planner.plan(document: Fixture.json(document)))
    }

    // Two clips of four seconds each, cut at 4, the second followed by a third so it has a clip after it.
    private func storyline(
        second keys: String?,
        secondIn: Double = 2
    ) -> String {
        let extra = keys.map { ", " + $0 } ?? ""
        return #"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 6 },
                { "media": "/abs/run.mp4", "in": \#(secondIn), "out": 6\#(extra) }, { "media": "/abs/run.mp4", "in": 0, "out": 2 } ] }
            """#
    }
}

//
//  SequenceAudioFilterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
import Testing

@testable import Frames

// `/abs/run.mp4` (30 seconds) holds picture and sound, `/abs/short.mp4` only a picture, `/abs/bgm.m4a` and `/abs/ding.wav`
// only sound.
@Suite("SequenceAudioFilter Tests")
struct SequenceAudioFilterTests {
    // MARK: - Property
    private let sut = Fixture.sequencePlanner
    private let checker = KeyChecker(mediaKinds: MediaKindTable(
        ["/abs/run.mp4": .video, "/abs/short.mp4": .video, "/abs/bgm.m4a": .audio],
        templates: []
    ))

    // MARK: - Initializer
    // MARK: - Test
    @Test("the key tables take a sequence's audio filter and keyframes that write it")
    func acceptsSequenceAudioFilter() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ],
              "audioFilter": [ "mine/limit", { "op": "limiter", "ceiling": -1 } ],
              "keyframes": [ { "at": 0, "audioFilter": [ { "args": { "boost": 0 } }, { "gain": 0 } ], "ease": "ease-in" },
                             { "at": 2, "audioFilter": [ { "args": { "boost": 3 } }, { "gain": 2 } ] } ] }
            """#)

        // When, Then
        try checker.check(document: document)
    }

    @Test(
        "the key tables refuse a sequence keyframe that writes another key, has no at or writes nothing",
        arguments: [
            #"[ { "at": 0, "opacity": 0 } ]"#,
            #"[ { "audioFilter": { "gain": 0 } } ]"#,
            #"[ { "at": 0 } ]"#,
            #"[ { "at": 0, "audioFilter": { "gain": 0 }, "ease": "wobble" } ]"#
        ]
    )
    func refusesSequenceKeyframes(keyframes: String) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "audioFilter": { "op": "limiter" }, "keyframes": \#(keyframes) }
            """#)

        // When, Then
        #expect(throws: (any Error).self) { try checker.check(document: document) }
    }

    @Test("a sequence's audio filter resolves in sequence time with its defaults written, and moves by its keyframes")
    func resolvesSequenceAudioFilter() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "audioFilter": { "op": "limiter", "lookahead": 0.01 },
              "keyframes": [ { "at": 1, "audioFilter": { "gain": 0 } }, { "at": 3, "audioFilter": { "gain": 4 } } ] }
            """#)

        // Then
        let limiter = try #require(limiter(of: plan.audioFilter, at: 2))
        #expect(limiter["gain"]?.number == 2)
        #expect(limiter["ceiling"]?.number == -1)
        #expect(limiter["release"]?.number == 0.1)
        #expect(limiter["lookahead"] == .fixed(.number(0.01)))
    }

    @Test("a sequence without an audio filter has none, and a sequence with no sound takes one")
    func takesAudioFilterOnSilence() throws {
        // When
        let plain = try plan(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ] }"#)
        let silent = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/short.mp4", "out": 4 } ], "audioFilter": { "op": "limiter" } }
            """#)

        // Then
        #expect(plain.audioFilter == .off)
        #expect(silent.sound.isEmpty)
        #expect(limiter(of: silent.audioFilter, at: 0) != nil)
    }

    @Test("a nested sequence's audio filter is carried on the sound of the compound clip that plays it, beside the clip's own")
    func carriesNestedAudioFilter() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "audio", "media": { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 2 } ],
                                      "audioFilter": { "op": "limiter", "ceiling": -6 } },
                           "at": 1, "audioFilter": { "op": "gate", "threshold": -50 } } ] }
            """#)

        // Then
        let nested = try #require(limiter(of: plan.sound[1].nestedAudioFilter, at: 0))
        #expect(nested["ceiling"]?.number == -6)
        #expect(limiter(of: plan.sound[1].audioFilter, at: 0) == nil)
        #expect(plan.sound[0].nestedAudioFilter == .off)
    }

    @Test("sequence keyframes that all lie after its end stop, naming the sequence")
    func refusesKeyframesAfterEnd() throws {
        // When, Then
        #expect(throws: ResolveError.keyframesOutsideVisibleRange(place: Place.root.appending(key: "keyframes"), kind: .sequence, leaf: "audioFilter.gain", visible: TimeRange(start: 0, end: 4))) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "audioFilter": { "op": "limiter" },
                  "keyframes": [ { "at": 5, "audioFilter": { "gain": 0 } }, { "at": 6, "audioFilter": { "gain": 3 } } ] }
                """#)
        }
    }

    @Test("a sequence keyframe that writes a lookahead or an argument a lookahead reads stops, naming the keyframe")
    func refusesKeyframedLookahead() throws {
        // When, Then
        #expect(throws: LookError.keyframedStatic(place: Place.root.appending(key: "keyframes").appending(index: 0).appending(key: "audioFilter").appending(key: "lookahead"))) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "audioFilter": { "op": "limiter" }, "keyframes": [ { "at": 0, "audioFilter": { "lookahead": 0.01 } } ] }
                """#)
        }
        #expect(throws: LookError.keyframedStatic(place: Place.root.appending(key: "keyframes").appending(index: 0).appending(key: "audioFilter").appending(key: "args").appending(key: "ahead"))) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "audioFilter": "mine/limit", "keyframes": [ { "at": 0, "audioFilter": { "args": { "ahead": 0.01 } } } ] }
                """#)
        }
    }

    @Test("a sequence's limiter parameter outside its range stops where the sequence writes it")
    func refusesOutOfRange() throws {
        // When, Then
        #expect(throws: LookError.outsideDomain(place: Place.root.appending(key: "audioFilter").appending(key: "ceiling"), value: 1, domain: .range(-Double.infinity...0))) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ], "audioFilter": { "op": "limiter", "ceiling": 1 } }
                """#)
        }
    }

    @Test("the resolved sequence writes its audio filter after audio, a lookahead as a plain number, and a compound clip's sound its nested one")
    func writesResolvedAudioFilter() throws {
        // Given
        let plan = try Fixture.documentPlanner.plan(Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "audio", "media": { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 2 } ],
                                      "audioFilter": { "op": "limiter", "ceiling": -6 } },
                           "at": 1 } ],
              "audioFilter": { "op": "limiter", "lookahead": 0.01 } }
            """#))

        // When
        let members = ResolvedSequenceWriter().members(of: try ResolvedSequence(plan: plan, hashes: FileHashTable()))

        // Then
        #expect(members.map(\.key) == ["format", "storyline", "clips", "audio", "audioFilter"])
        let filter = members.last?.value.arrayValue?.first?.objectValue
        let limiter = filter?["ops"]?.arrayValue?.first?.objectValue
        #expect(limiter?["op"] == .string("limiter"))
        #expect(limiter?["lookahead"] == .number(0.01))
        #expect(limiter?["gain"]?.arrayValue?.count == 1)
        let audio = members.first { $0.key == "audio" }?.value.arrayValue ?? []
        #expect(audio.first?.objectValue?["nested"] == .null)
        let nested = audio.last?.objectValue?["nested"]?.objectValue?["audioFilter"]?.arrayValue?.first?.objectValue
        let ceiling = nested?["ops"]?.arrayValue?.first?.objectValue?["ceiling"]?.arrayValue?.first?.objectValue
        #expect(ceiling?["value"] == .number(-6))
        #expect(audio.last?.objectValue?["audioFilter"] == .null)
    }

    @Test("a sequence's convolve resolves to its absolute file in sequence time, and one whose file has no sound stops at the sequence's audio filter")
    func resolvesSequenceConvolution() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "audioFilter": { "op": "convolve", "file": "/abs/ding.wav", "mix": 0.4 },
              "keyframes": [ { "at": 1, "audioFilter": { "gain": 0 } }, { "at": 3, "audioFilter": { "gain": -8 } } ] }
            """#)
        let error = #expect(throws: ResolveError.self) {
            try self.plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ], "audioFilter": { "op": "convolve", "file": "/abs/short.mp4" } }
                """#)
        }

        // Then
        guard
            case let .list(entries) = plan.audioFilter.sampled(at: 2, as: LookStructureTable.resolvedAudioFilter),
            case let .list(operations)? = entries.first?["ops"],
            case let .form("op:convolve", body)? = operations.first
        else {
            Issue.record("expected a convolve, got \(plan.audioFilter)")
            return
        }
        #expect(body["gain"]?.number == -4)
        #expect(entries.first?["mix"]?.number == 0.4)
        guard case let .list(timed) = plan.audioFilter, case let .list(timedOperations)? = timed.first?["ops"],
            case let .form(_, timedBody)? = timedOperations.first
        else {
            Issue.record("expected one op, got \(plan.audioFilter)")
            return
        }
        #expect(timedBody["file"] == .fixed(.string("/abs/ding.wav")))
        #expect(error == .unusableImpulseResponse(place: Place.root.appending(key: "audioFilter"), kind: .sequence, reference: "/abs/short.mp4", refusal: .noSound))
    }

    // MARK: - Private
    @discardableResult
    private func plan(_ document: String) throws -> SequencePlan {
        try sut.plan(Fixture.planner.plan(document: Fixture.json(document)))
    }

    private func limiter(
        of filter: TimedValue,
        at time: Double
    ) -> SampledValue? {
        guard
            case let .list(entries) = filter.sampled(at: time, as: LookStructureTable.resolvedAudioFilter),
            case let .list(operations)? = entries.last?["ops"],
            case let .form("op:limiter", body)? = operations.first
        else {
            return nil
        }

        return body
    }
}

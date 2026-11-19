//
//  AudioFilterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import Testing

@testable import Frames

// `/abs/run.mp4` (30 seconds) holds picture and sound, `/abs/short.mp4` only a picture, `/abs/bgm.m4a` only sound.
@Suite("AudioFilter Tests")
struct AudioFilterTests {
    // MARK: - Property
    private let sut = Fixture.sequencePlanner
    private let checker = KeyChecker(mediaKinds: MediaKindTable(
        ["/abs/run.mp4": .video, "/abs/bgm.m4a": .audio],
        templates: []
    ))
    private let clip = Place(components: [.key("clips"), .index(0, id: nil)])

    // MARK: - Initializer
    // MARK: - Test
    @Test("an audio filter is a list of entries {ops, mix}, each op with its defaults written")
    func resolvesEntriesWithDefaults() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "media": "/abs/bgm.m4a", "audioFilter": [
                { "op": "eq", "bands": [ { "type": "highPass", "frequency": 80 }, { "type": "peak", "frequency": 3000, "gain": 3, "q": 1 } ] },
                { "op": "compressor", "threshold": -18, "ratio": 3, "mix": 0.5 } ] } ] }
            """#)

        // Then
        let filter = plan.sound[1].audioFilter.sampled(at: 0, as: LookStructureTable.resolvedAudioFilter)
        guard case let .list(entries) = filter, entries.count == 2 else {
            Issue.record("expected two entries, got \(filter)")
            return
        }
        #expect(entries[0]["mix"]?.number == 1)
        #expect(entries[1]["mix"]?.number == 0.5)
        let eq = try #require(operation(of: entries[0]))
        #expect(eq.name == "op:eq")
        guard case let .list(bands) = eq.body["bands"] else {
            Issue.record("expected a list of bands")
            return
        }
        #expect(bands[0]["type"]?.name == "highPass")
        #expect(bands[0]["frequency"]?.number == 80)
        #expect(bands[0]["q"]?.number == 0.7071)
        #expect(bands[1]["gain"]?.number == 3)
        let compressor = try #require(operation(of: entries[1]))
        #expect(compressor.name == "op:compressor")
        #expect(compressor.body["knee"]?.number == 0)
        #expect(compressor.body["attack"]?.number == 0.01)
        #expect(compressor.body["release"]?.number == 0.1)
        #expect(compressor.body["makeup"]?.number == 0)
        #expect(compressor.body["mix"] == nil)
    }

    @Test("a band's frequency and q written only in keyframes interpolate in log space, above 0 under an overshoot")
    func interpolatesBandInLogSpace() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "media": "/abs/bgm.m4a", "at": 0,
                "audioFilter": { "op": "eq", "bands": [ { "type": "peak", "gain": 6 } ] },
                "keyframes": [
                  { "at": 0, "audioFilter": { "bands": [ { "frequency": 100, "q": 10 } ] }, "ease": "back-out" },
                  { "at": 2, "audioFilter": { "bands": [ { "frequency": 10000, "q": 0.1 } ] } } ] } ] }
            """#)

        // Then
        let fractions = (1..<200).map { Double($0) / 200 }
        let peak = try #require(fractions.max { Ease.backOut.value(at: $0) < Ease.backOut.value(at: $1) })
        let progress = Ease.backOut.value(at: peak)
        let band = try #require(band(of: plan.sound[1].audioFilter, at: peak * 2))
        let frequency = try #require(band["frequency"]?.number)
        let q = try #require(band["q"]?.number)
        #expect(abs(frequency - 100 * pow(100, progress)) < 1e-6)
        #expect(abs(q - 10 * pow(0.01, progress)) < 1e-9)
        #expect(q > 0)
        #expect(band["gain"]?.number == 6)
    }

    @Test("a band whose frequency neither the clip nor its keyframes write stops")
    func refusesBandWithoutFrequency() throws {
        // When, Then
        #expect(throws: ResolveError.missingLookLeaf(place: clip.appending(key: "audioFilter"), kind: .clip(.media(.audio)), key: "frequency", layer: nil)) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "media": "/abs/bgm.m4a", "audioFilter": { "op": "eq", "bands": [ { "type": "peak", "gain": 6 } ] },
                    "keyframes": [ { "at": 0, "audioFilter": { "bands": [ { "q": 2 } ] } }, { "at": 1, "audioFilter": { "bands": [ { "q": 4 } ] } } ] } ] }
                """#)
        }
    }

    @Test("a static parameter outside its range stops where the clip writes it")
    func refusesOutOfRange() throws {
        // When, Then
        #expect(throws: LookError.outsideDomain(place: clip.appending(key: "audioFilter").appending(key: "bands").appending(index: 0).appending(key: "frequency"), value: 30000)) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "media": "/abs/bgm.m4a", "audioFilter": { "op": "eq", "bands": [ { "type": "lowPass", "frequency": 30000 } ] } } ] }
                """#)
        }
        #expect(throws: LookError.outsideDomain(place: clip.appending(key: "audioFilter").appending(key: "ratio"), value: 0.5)) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "media": "/abs/bgm.m4a", "audioFilter": { "op": "compressor", "threshold": -20, "ratio": 0.5 } } ] }
                """#)
        }
    }

    @Test("a keyframe that writes an op stops, since the structure of an audio filter is static")
    func refusesOperationInKeyframe() throws {
        // When, Then
        #expect(throws: (any Error).self) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "media": "/abs/bgm.m4a", "audioFilter": { "op": "gate", "threshold": -50 },
                    "keyframes": [ { "at": 0, "audioFilter": { "op": "compressor", "threshold": -20, "ratio": 2 } } ] } ] }
                """#)
        }
    }

    @Test("an audio filter on a clip that plays no sound stops")
    func refusesSilentClip() throws {
        // When, Then
        #expect(throws: ResolveError.audioFilterWithoutSound(place: clip.appending(key: "audioFilter"), kind: .clip(.media(.video)))) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "media": "/abs/short.mp4", "audioFilter": { "op": "gate", "threshold": -50 } } ] }
                """#)
        }
    }

    @Test(
        "the key tables refuse an audio filter on a compound clip and its sound, a gain on a pass band and an unknown op",
        arguments: [
            (#"{ "media": { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ] }, "audioFilter": { "op": "gate", "threshold": -50 } }"#, "audioFilter"),
            (#"{ "media": { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ] }, "picture": false, "audioFilter": { "op": "gate", "threshold": -50 } }"#, "audioFilter"),
            (#"{ "media": "/abs/bgm.m4a", "audioFilter": { "op": "eq", "bands": [ { "type": "lowPass", "frequency": 100, "gain": 3 } ] } }"#, "gain")
        ]
    )
    func refusesKeys(clip: String, key: String) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ \#(clip) ] }"#)

        // When, Then
        let error = #expect(throws: ModelError.self) { try checker.check(document: document) }
        guard case let .unknownKey(_, _, refused, _) = error else {
            Issue.record("expected an unknown key, got \(String(describing: error))")
            return
        }
        #expect(refused == key)
    }

    @Test("the key tables refuse an empty list, an empty eq and an unknown op")
    func refusesShapes() throws {
        for filter in [#"[]"#, #"{ "op": "eq", "bands": [] }"#, #"{ "op": "reverb" }"#] {
            // Given
            let document = try Fixture.json(#"""
                { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4" } ], "clips": [ { "media": "/abs/bgm.m4a", "audioFilter": \#(filter) } ] }
                """#)

            // When, Then
            #expect(throws: ModelError.self) { try checker.check(document: document) }
        }
    }

    @Test("a video clip and an audio clip take an audio filter and its keyframes")
    func acceptsAudioFilter() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "audioFilter": { "op": "gate", "threshold": -50 },
                "keyframes": [ { "at": 0, "audioFilter": { "mix": 0 } }, { "at": 1, "audioFilter": { "mix": 1 } } ] } ],
              "clips": [ { "media": "/abs/run.mp4", "picture": false, "audioFilter": [ { "op": "eq", "bands": [ { "type": "highPass", "frequency": 80 } ] } ] },
                         { "media": "/abs/bgm.m4a", "audioFilter": { "op": "compressor", "threshold": -18, "ratio": 3 } } ] }
            """#)

        // When, Then
        try checker.check(document: document)
    }

    // MARK: - Private
    @discardableResult
    private func plan(_ document: String) throws -> SequencePlan {
        try sut.plan(Fixture.planner.plan(document: Fixture.json(document)))
    }

    private func operation(of entry: SampledValue) -> (name: String, body: SampledValue)? {
        guard case let .list(operations) = entry["ops"], case let .form(name, body) = operations.first else { return nil }

        return (name, body)
    }

    private func band(
        of filter: TimedValue,
        at time: Double
    ) -> SampledValue? {
        guard
            case let .list(entries) = filter.sampled(at: time, as: LookStructureTable.resolvedAudioFilter),
            let entry = entries.first,
            let operation = operation(of: entry),
            case let .list(bands) = operation.body["bands"]
        else {
            return nil
        }

        return bands.first
    }
}

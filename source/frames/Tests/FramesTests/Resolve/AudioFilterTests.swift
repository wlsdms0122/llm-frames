//
//  AudioFilterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

import Foundation
import Testing

@testable import Frames

// `/abs/run.mp4` (30 seconds) holds picture and sound, `/abs/short.mp4` only a picture, `/abs/bgm.m4a` and `/abs/ding.wav`
// only sound, and `/abs/card.png` is a still.
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
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": [
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
        guard case let .list(bands) = eq.body["bands"], bands.count == 2,
            case let .form(firstType, first) = bands[0], case let .form(secondType, second) = bands[1]
        else {
            Issue.record("expected two bands, each a form by its type")
            return
        }
        #expect(firstType == "type:highPass")
        #expect(first["frequency"]?.number == 80)
        #expect(first["q"]?.number == 0.7071)
        #expect(first["gain"] == nil)
        #expect(secondType == "type:peak")
        #expect(second["gain"]?.number == 3)
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
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "at": 0,
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

    @Test("a peak band whose gain only keyframes write passes the key tables and sweeps its gain")
    func sweepsKeyframedGain() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "at": 0,
                "audioFilter": { "op": "eq", "bands": [ { "type": "peak", "frequency": 1000 } ] },
                "keyframes": [
                  { "at": 0, "audioFilter": { "bands": [ { "gain": 0 } ] } },
                  { "at": 2, "audioFilter": { "bands": [ { "gain": 6 } ] } } ] } ] }
            """#
        try checker.check(document: Fixture.json(document))

        // When
        let plan = try plan(document)

        // Then
        let band = try #require(band(of: plan.sound[1].audioFilter, at: 1))
        #expect(band["gain"]?.number == 3)
        #expect(band["frequency"]?.number == 1000)
    }

    @Test("a shelf band whose gain neither the clip nor its keyframes write stops")
    func refusesBandWithoutGain() throws {
        // When, Then
        #expect(throws: ResolveError.missingLookLeaf(place: clip.appending(key: "audioFilter"), kind: .clip(.media(.audio)), key: "gain", layer: nil)) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "eq", "bands": [ { "type": "lowShelf", "frequency": 200 } ] } } ] }
                """#)
        }
    }

    @Test("a compressor whose threshold only keyframes write passes the key tables and moves its threshold")
    func sweepsKeyframedThreshold() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "at": 0, "audioFilter": { "op": "compressor", "ratio": 4 },
                "keyframes": [
                  { "at": 0, "audioFilter": { "threshold": -10 } },
                  { "at": 2, "audioFilter": { "threshold": -30 } } ] } ] }
            """#
        try checker.check(document: Fixture.json(document))

        // When
        let plan = try plan(document)

        // Then
        let filter = plan.sound[1].audioFilter.sampled(at: 1, as: LookStructureTable.resolvedAudioFilter)
        guard case let .list(entries) = filter, let entry = entries.first else {
            Issue.record("expected an entry, got \(filter)")
            return
        }
        let compressor = try #require(operation(of: entry))
        #expect(compressor.body["threshold"]?.number == -20)
    }

    @Test("a compressor whose threshold neither the clip nor its keyframes write stops")
    func refusesCompressorWithoutThreshold() throws {
        // When, Then
        #expect(throws: ResolveError.missingLookLeaf(place: clip.appending(key: "audioFilter"), kind: .clip(.media(.audio)), key: "threshold", layer: nil)) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "compressor", "ratio": 4 } } ] }
                """#)
        }
    }

    @Test("an op's parameter outside its domain passes the key check and stops where the clip writes it")
    func refusesParameterOutsideDomain() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "gate", "threshold": -40, "attack": 0 } } ] }
            """#
        try checker.check(document: Fixture.json(document))

        // When, Then
        let error = #expect(throws: LookError.outsideDomain(place: clip.appending(key: "audioFilter").appending(key: "attack"), value: 0, domain: .positive)) {
            try plan(document)
        }
        #expect(error?.description == "clips[0].audioFilter.attack: 0 is not above 0")
    }

    @Test("a preset argument two keyframes write may put an attack at 0 at one of them, and one keyframe may not")
    func takesSampledAttackAtZero() throws {
        // Given
        let clip = { (keyframes: String) in
            #"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "at": 0, "audioFilter": "mine/gate", "keyframes": \#(keyframes) } ] }
                """#
        }

        // When
        let plan = try plan(clip(#"[ { "at": 0, "audioFilter": { "args": { "attack": 0.01 } } }, { "at": 2, "audioFilter": { "args": { "attack": 0 } } } ]"#))

        // Then
        let filter = plan.sound[1].audioFilter.sampled(at: 1, as: LookStructureTable.resolvedAudioFilter)
        guard case let .list(entries) = filter, let entry = entries.first else {
            Issue.record("expected an entry, got \(filter)")
            return
        }
        let gate = try #require(operation(of: entry))
        #expect(gate.body["attack"]?.number == 0.005)
        let error = #expect(throws: PresetError.self) {
            try self.plan(clip(#"[ { "at": 0, "audioFilter": { "args": { "attack": 0 } } } ]"#))
        }
        guard case let .rejectedArguments(place, _, _, _) = error else {
            Issue.record("expected rejected arguments, got \(String(describing: error))")
            return
        }
        #expect(place == self.clip.appending(key: "keyframes").appending(index: 0).appending(key: "audioFilter"))
    }

    @Test("a preset entry is its preset's ops with its arguments in place and their defaults written, and its mix")
    func expandsPreset() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": [ "mine/voice", { "preset": "mine/voice", "args": { "cut": 120 }, "mix": 0.5 } ] } ] }
            """#)

        // Then
        let filter = plan.sound[1].audioFilter.sampled(at: 0, as: LookStructureTable.resolvedAudioFilter)
        guard case let .list(entries) = filter, entries.count == 2 else {
            Issue.record("expected two entries, got \(filter)")
            return
        }
        #expect(entries[0]["mix"]?.number == 1)
        #expect(entries[1]["mix"]?.number == 0.5)
        guard case let .list(operations) = entries[1]["ops"], operations.count == 2,
            case let .form("op:eq", eq) = operations[0], case let .form("op:compressor", compressor) = operations[1],
            case let .list(bands) = eq["bands"], case let .form(_, highPass) = bands.first
        else {
            Issue.record("expected an eq and a compressor, got \(entries[1])")
            return
        }
        #expect(highPass["frequency"]?.number == 120)
        #expect(highPass["q"]?.number == 0.7071)
        #expect(compressor["ratio"]?.number == 3)
        #expect(compressor["knee"]?.number == 0)
        let first = try #require(band(of: plan.sound[1].audioFilter, at: 0))
        #expect(first["frequency"]?.number == 80)
    }

    @Test("a preset argument keyframed sweeps the parameter it fills, in log space for a frequency")
    func sweepsPresetArgument() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "at": 0, "audioFilter": "mine/voice",
                "keyframes": [ { "at": 0, "audioFilter": { "args": { "cut": 100 } } }, { "at": 2, "audioFilter": { "args": { "cut": 10000 } } } ] } ] }
            """#)

        // Then
        let band = try #require(band(of: plan.sound[1].audioFilter, at: 1))
        let frequency = try #require(band["frequency"]?.number)
        #expect(abs(frequency - 1000) < 1e-6)
    }

    @Test("a preset argument outside the range of the parameter it fills stops, statically and in a keyframe")
    func refusesPresetArgumentOutOfRange() throws {
        // When, Then
        #expect(throws: PresetError.self) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "preset": "mine/voice", "args": { "squash": 0.5 } } } ] }
                """#)
        }
        let error = #expect(throws: PresetError.self) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": "mine/voice",
                    "keyframes": [ { "at": 0, "audioFilter": { "args": { "squash": 0.5 } } } ] } ] }
                """#)
        }
        guard case let .rejectedArguments(place, _, _, _) = error else {
            Issue.record("expected rejected arguments, got \(String(describing: error))")
            return
        }
        #expect(place == clip.appending(key: "keyframes").appending(index: 0).appending(key: "audioFilter"))
    }

    @Test("an audio preset that no pack holds stops as an unknown audio preset")
    func refusesUnknownPreset() throws {
        // When, Then
        #expect(throws: ResolveError.unknownPreset(place: clip.appending(key: "audioFilter"), kind: .clip(.media(.audio)), preset: UnknownPreset(kind: .audio, name: "mine/none", hint: .pack(pack: "mine", names: ["mine/gate", "mine/limit", "mine/voice"], nearest: nil)))) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": "mine/none" } ] }
                """#)
        }
    }

    @Test("a band whose frequency neither the clip nor its keyframes write stops")
    func refusesBandWithoutFrequency() throws {
        // When, Then
        #expect(throws: ResolveError.missingLookLeaf(place: clip.appending(key: "audioFilter"), kind: .clip(.media(.audio)), key: "frequency", layer: nil)) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "eq", "bands": [ { "type": "peak", "gain": 6 } ] },
                    "keyframes": [ { "at": 0, "audioFilter": { "bands": [ { "q": 2 } ] } }, { "at": 1, "audioFilter": { "bands": [ { "q": 4 } ] } } ] } ] }
                """#)
        }
    }

    @Test("a static parameter outside its range stops where the clip writes it")
    func refusesOutOfRange() throws {
        // When, Then
        #expect(throws: LookError.outsideDomain(place: clip.appending(key: "audioFilter").appending(key: "bands").appending(index: 0).appending(key: "frequency"), value: 30000, domain: .between(0, 24000))) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "eq", "bands": [ { "type": "lowPass", "frequency": 30000 } ] } } ] }
                """#)
        }
        #expect(throws: LookError.outsideDomain(place: clip.appending(key: "audioFilter").appending(key: "ratio"), value: 0.5, domain: .range(1...Double.infinity))) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "compressor", "threshold": -20, "ratio": 0.5 } } ] }
                """#)
        }
    }

    @Test("a keyframe that writes an op stops, since the structure of an audio filter is static")
    func refusesOperationInKeyframe() throws {
        // When, Then
        #expect(throws: (any Error).self) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "gate", "threshold": -50 },
                    "keyframes": [ { "at": 0, "audioFilter": { "op": "compressor", "threshold": -20, "ratio": 2 } } ] } ] }
                """#)
        }
    }

    @Test("an audio filter on a clip that plays no sound stops")
    func refusesSilentClip() throws {
        // When, Then
        #expect(throws: ResolveError.audioFilterWithoutSound(place: clip.appending(key: "audioFilter"), kind: .clip(.media(.video)))) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/short.mp4", "audioFilter": { "op": "gate", "threshold": -50 } } ] }
                """#)
        }
    }

    @Test(
        "the key tables refuse a gain on a pass band",
        arguments: [
            (#"{ "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "eq", "bands": [ { "type": "lowPass", "frequency": 100, "gain": 3 } ] } }"#, "gain")
        ]
    )
    func refusesKeys(clip: String, key: String) throws {
        // Given
        let document = try Fixture.json(#"{ "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [ \#(clip) ] }"#)

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
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": \#(filter) } ] }
                """#)

            // When, Then
            #expect(throws: ModelError.self) { try checker.check(document: document) }
        }
    }

    @Test("a video clip and an audio clip take an audio filter and its keyframes")
    func acceptsAudioFilter() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "audioFilter": { "op": "gate", "threshold": -50 },
                "keyframes": [ { "at": 0, "audioFilter": { "mix": 0 } }, { "at": 1, "audioFilter": { "mix": 1 } } ] } ],
              "clips": [ { "kind": "media", "media": "/abs/run.mp4", "picture": false, "audioFilter": [ { "op": "eq", "bands": [ { "type": "highPass", "frequency": 80 } ] } ] },
                         { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "compressor", "threshold": -18, "ratio": 3 } } ] }
            """#)

        // When, Then
        try checker.check(document: document)
    }

    @Test("the key tables take an audio filter and its keyframes on a compound clip, a storyline one and its sound alone")
    func acceptsCompoundAudioFilter() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence",
              "storyline": [ { "kind": "media", "media": { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }, "audioFilter": { "op": "limiter" },
                "keyframes": [ { "at": 0, "audioFilter": { "gain": 0 } }, { "at": 1, "audioFilter": { "gain": 3 } } ] } ],
              "clips": [ { "kind": "media", "media": { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }, "audioFilter": { "op": "gate", "threshold": -50 } },
                         { "kind": "media", "media": { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ] }, "picture": false, "audioFilter": { "op": "gate", "threshold": -50 },
                           "keyframes": [ { "at": 0, "audioFilter": { "mix": 0 } }, { "at": 1, "audioFilter": { "mix": 1 } } ] } ] }
            """#)

        // When, Then
        try checker.check(document: document)
    }

    @Test("a compound clip's audio filter resolves on its sound, its keyframes in sequence time as a sequence clip's are")
    func resolvesCompoundAudioFilter() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 2 } ] }, "picture": false, "at": 1,
                "audioFilter": { "op": "limiter", "ceiling": -3 },
                "keyframes": [ { "at": 0, "audioFilter": { "gain": 0 } }, { "at": 1, "audioFilter": { "gain": 6 } } ] } ] }
            """#)

        // Then
        #expect(plan.sound[1].nested.count == 1)
        let limiter = try #require(sampledLimiter(of: plan.sound[1].audioFilter, at: 0.5))
        #expect(limiter["gain"]?.number == 3)
        #expect(limiter["ceiling"]?.number == -3)
    }

    @Test("an audio filter on a compound clip none of whose clips has sound stops")
    func refusesSilentCompoundClip() throws {
        // When, Then
        #expect(throws: ResolveError.audioFilterWithoutSound(place: clip.appending(key: "audioFilter"), kind: .clip(.media(.sequence)))) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/short.mp4" } ] }, "audioFilter": { "op": "gate", "threshold": -50 } } ] }
                """#)
        }
    }

    @Test("a limiter resolves with its defaults written and its lookahead a plain number")
    func resolvesLimiterWithDefaults() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "limiter" } } ] }
            """#)

        // Then
        guard case let .list(entries) = plan.sound[1].audioFilter, case let .list(operations)? = entries.first?["ops"],
            case let .form("op:limiter", limiter)? = operations.first
        else {
            Issue.record("expected one limiter, got \(plan.sound[1].audioFilter)")
            return
        }
        #expect(limiter["lookahead"] == .fixed(.number(0.005)))
        let sampled = try #require(operation(of: limiter, at: 0))
        #expect(sampled["gain"]?.number == 0)
        #expect(sampled["ceiling"]?.number == -1)
        #expect(sampled["release"]?.number == 0.1)
    }

    @Test("a limiter's gain, ceiling and release move under keyframes, and a ceiling an ease carries past 0 is clamped")
    func sweepsLimiter() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "at": 0, "audioFilter": { "op": "limiter", "lookahead": 0.01 },
                "keyframes": [
                  { "at": 0, "audioFilter": { "gain": 0, "ceiling": -6, "release": 0.1 }, "ease": "back-out" },
                  { "at": 2, "audioFilter": { "gain": 6, "ceiling": 0, "release": 0.3 } } ] } ] }
            """#)

        // Then
        let middle = try #require(sampledLimiter(of: plan.sound[1].audioFilter, at: 1.5))
        #expect(middle["ceiling"]?.number == 0)
        #expect(middle["lookahead"] == .fixed(.number(0.01)))
        let start = try #require(sampledLimiter(of: plan.sound[1].audioFilter, at: 0))
        #expect(start["gain"]?.number == 0)
        #expect(start["release"]?.number == 0.1)
    }

    @Test(
        "a limiter's parameter outside its range stops where the clip writes it",
        arguments: [
            (#"{ "op": "limiter", "ceiling": 0.5 }"#, "ceiling", 0.5, NumberDomain.range(-Double.infinity...0)),
            (#"{ "op": "limiter", "lookahead": 0.001 }"#, "lookahead", 0.001, NumberDomain.range(0.0015...0.05)),
            (#"{ "op": "limiter", "lookahead": 0.06 }"#, "lookahead", 0.06, NumberDomain.range(0.0015...0.05)),
            (#"{ "op": "limiter", "release": 0 }"#, "release", 0, NumberDomain.positive)
        ]
    )
    func refusesLimiterOutOfRange(
        filter: String,
        key: String,
        value: Double,
        domain: NumberDomain
    ) throws {
        // When, Then
        #expect(throws: LookError.outsideDomain(place: clip.appending(key: "audioFilter").appending(key: key), value: value, domain: domain)) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": \#(filter) } ] }
                """#)
        }
    }

    @Test(
        "a limiter's parameter at the edge of its range resolves as written",
        arguments: [
            (#"{ "op": "limiter", "ceiling": 0 }"#, "ceiling", 0.0),
            (#"{ "op": "limiter", "lookahead": 0.0015 }"#, "lookahead", 0.0015),
            (#"{ "op": "limiter", "lookahead": 0.05 }"#, "lookahead", 0.05)
        ]
    )
    func takesLimiterAtRangeEdge(
        filter: String,
        key: String,
        value: Double
    ) throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": \#(filter) } ] }
            """#)

        // Then
        let limiter = try #require(sampledLimiter(of: plan.sound[1].audioFilter, at: 0))
        #expect(limiter[key]?.number == value || limiter[key] == .fixed(.number(value)))
    }

    @Test("a resolved limiter is planned as a limiter op, its lookahead static, its held values numbers and its gain moving")
    func plansLimiter() throws {
        // Given
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "at": 0, "audioFilter": { "op": "limiter", "lookahead": 0.01 },
                "keyframes": [ { "at": 0, "audioFilter": { "gain": 0 } }, { "at": 2, "audioFilter": { "gain": 6 } } ] } ] }
            """#)

        // When
        let mix = MixPlanner().mix(of: try ResolvedSequence(plan: plan, hashes: FileHashTable()))

        // Then
        let filter = try #require(mix.segments.first { !$0.filter.isEmpty }?.filter)
        guard case let .limiter(limiter)? = filter.first?.operations.first, case let .envelope(gain) = limiter.gain else {
            Issue.record("expected a limiter whose gain moves, got \(filter)")
            return
        }
        #expect(filter.first?.mix == .constant(1))
        #expect(limiter.lookahead == 0.01)
        #expect(limiter.ceiling == .constant(-1))
        #expect(limiter.release == .constant(0.1))
        #expect(gain.first == EnvelopePoint(time: 0, value: 0))
        #expect(gain.first { $0.time == 1 }?.value == 3)
        #expect(gain.last?.value == 6)
    }

    @Test("a keyframe that writes a limiter's lookahead stops, naming the keyframe")
    func refusesKeyframedLookahead() throws {
        // When, Then
        #expect(throws: LookError.keyframedStatic(place: clip.appending(key: "keyframes").appending(index: 1).appending(key: "audioFilter").appending(key: "lookahead"))) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "at": 0, "audioFilter": { "op": "limiter" },
                    "keyframes": [ { "at": 0, "audioFilter": { "gain": 0 } }, { "at": 2, "audioFilter": { "lookahead": 0.01 } } ] } ] }
                """#)
        }
    }

    @Test("a preset's limiter takes its lookahead from an argument, and a keyframe that writes that argument stops")
    func refusesKeyframedLookaheadArgument() throws {
        // Given
        let document = { (keyframes: String) in
            #"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "at": 0, "audioFilter": { "preset": "mine/limit", "args": { "ahead": 0.02 } },
                    "keyframes": \#(keyframes) } ] }
                """#
        }

        // When
        let plan = try plan(document(#"[ { "at": 0, "audioFilter": { "args": { "boost": 0 } } }, { "at": 2, "audioFilter": { "args": { "boost": 4 } } } ]"#))

        // Then
        let limiter = try #require(sampledLimiter(of: plan.sound[1].audioFilter, at: 1))
        #expect(limiter["lookahead"] == .fixed(.number(0.02)))
        #expect(limiter["gain"]?.number == 2)
        #expect(throws: LookError.keyframedStatic(place: clip.appending(key: "keyframes").appending(index: 0).appending(key: "audioFilter").appending(key: "args").appending(key: "ahead"))) {
            try self.plan(document(#"[ { "at": 0, "audioFilter": { "args": { "ahead": 0.01 } } } ]"#))
        }
    }

    @Test("the key tables take a limiter on a clip and in its keyframes")
    func acceptsLimiter() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "limiter", "gain": 3, "ceiling": -1, "lookahead": 0.005, "release": 0.1, "mix": 1 },
                "keyframes": [ { "at": 0, "audioFilter": { "gain": 0 } } ] } ] }
            """#)

        // When, Then
        try checker.check(document: document)
    }

    @Test("the key tables take a convolve with its file, gain and mix, and keyframes that write its gain and mix")
    func acceptsConvolution() throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "convolve", "file": "/abs/ding.wav", "gain": -6, "mix": 0 },
                "keyframes": [ { "at": 0, "audioFilter": { "gain": -12, "mix": 0 } }, { "at": 1, "audioFilter": { "gain": 0, "mix": 1 } } ] } ] }
            """#)

        // When, Then
        try checker.check(document: document)
    }

    @Test("a convolve whose file neither the clip nor its keyframes write passes the key tables and stops")
    func refusesConvolutionWithoutFile() throws {
        // Given
        let document = #"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "convolve", "gain": -6 } } ] }
            """#
        try checker.check(document: Fixture.json(document))

        // When, Then
        #expect(throws: ResolveError.missingLookLeaf(place: clip.appending(key: "audioFilter"), kind: .clip(.media(.audio)), key: "file", layer: nil)) {
            try plan(document)
        }
    }

    @Test(
        "the key tables refuse a convolve's unknown key, a file that is no name and a gain that is no number",
        arguments: [
            #"{ "op": "convolve", "file": "/abs/ding.wav", "decay": 2 }"#,
            #"{ "op": "convolve", "file": 3 }"#,
            #"{ "op": "convolve", "file": "/abs/ding.wav", "gain": "loud" }"#
        ]
    )
    func refusesConvolutionKeys(filter: String) throws {
        // Given
        let document = try Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4" } ], "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": \#(filter) } ] }
            """#)

        // When, Then
        #expect(throws: ModelError.self) { try checker.check(document: document) }
    }

    @Test("a convolve's mix outside 0 to 1 stops where the clip writes it")
    func refusesConvolutionMixOutOfRange() throws {
        // When, Then
        #expect(throws: LookError.outsideDomain(place: clip.appending(key: "audioFilter").appending(key: "mix"), value: 1.5, domain: .range(0...1))) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "convolve", "file": "/abs/ding.wav", "mix": 1.5 } } ] }
                """#)
        }
    }

    @Test("a convolve written in place resolves to its absolute file and its gain at 0, its entry's mix beside it")
    func resolvesConvolutionInPlace() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "convolve", "file": "/abs/ding.wav", "mix": 0.3 } } ] }
            """#)

        // Then
        let filter = plan.sound[1].audioFilter.sampled(at: 0, as: LookStructureTable.resolvedAudioFilter)
        guard case let .list(entries) = filter, let entry = entries.first else {
            Issue.record("expected an entry, got \(filter)")
            return
        }
        let convolution = try #require(operation(of: entry))
        #expect(convolution.name == "op:convolve")
        #expect(convolution.body["gain"]?.number == 0)
        #expect(convolution.body["mix"] == nil)
        #expect(entry["mix"]?.number == 0.3)
        guard case let .list(entries) = plan.sound[1].audioFilter, case let .list(operations)? = entries.first?["ops"],
            case let .form(_, body)? = operations.first
        else {
            Issue.record("expected one op, got \(plan.sound[1].audioFilter)")
            return
        }
        #expect(body["file"] == .fixed(.string("/abs/ding.wav")))
    }

    @Test("a compound clip's convolve resolves on its sound, and its nested sequence's beside it")
    func resolvesCompoundConvolution() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 2 } ],
                                      "audioFilter": { "op": "convolve", "file": "/abs/bgm.m4a" } },
                           "picture": false, "audioFilter": { "op": "convolve", "file": "/abs/ding.wav", "gain": -3 } } ] }
            """#)

        // Then
        #expect(file(of: plan.sound[1].audioFilter) == "/abs/ding.wav")
        #expect(file(of: plan.sound[1].nestedAudioFilter) == "/abs/bgm.m4a")
    }

    @Test(
        "an impulse response that is no sound an impulse response can be stops, naming the entry that writes it",
        arguments: [
            (#"{ "op": "convolve", "file": "/abs/card.png" }"#, "/abs/card.png", ImpulseResponseRefusal.noSound, false),
            (#"[ { "op": "gate", "threshold": -50 }, { "op": "convolve", "file": "/abs/short.mp4" } ]"#, "/abs/short.mp4", .noSound, true)
        ]
    )
    func refusesImpulseResponse(
        filter: String,
        reference: String,
        refusal: ImpulseResponseRefusal,
        isList: Bool
    ) throws {
        // Given
        let place = isList ? clip.appending(key: "audioFilter").appending(index: 1) : clip.appending(key: "audioFilter")

        // When
        let error = #expect(throws: ResolveError.self) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": \#(filter) } ] }
                """#)
        }

        // Then
        #expect(error == .unusableImpulseResponse(place: place, kind: .clip(.media(.audio)), reference: reference, refusal: refusal))
    }

    @Test("an impulse response of exactly 30 seconds, the sound of a video, is taken")
    func takesLongestImpulseResponse() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "audioFilter": { "op": "convolve", "file": "/abs/run.mp4" } } ] }
            """#)

        // Then
        #expect(file(of: plan.sound[1].audioFilter) == "/abs/run.mp4")
    }

    @Test("a convolve's gain moves under two keyframes and holds as a number under none, in the mix plan")
    func plansConvolution() throws {
        // Given
        let moving = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "at": 0, "audioFilter": { "op": "convolve", "file": "/abs/ding.wav" },
                "keyframes": [ { "at": 0, "audioFilter": { "gain": -12 } }, { "at": 2, "audioFilter": { "gain": 0 } } ] } ] }
            """#)
        let held = try plan(#"""
            { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "at": 0, "audioFilter": { "op": "convolve", "file": "/abs/ding.wav", "gain": -6 } } ] }
            """#)

        // When
        let hashes = FileHashTable(["/abs/ding.wav": "ding-digest"])
        let movingFilter = MixPlanner().mix(of: try ResolvedSequence(plan: moving, hashes: hashes)).segments.first { !$0.filter.isEmpty }?.filter
        let heldFilter = MixPlanner().mix(of: try ResolvedSequence(plan: held, hashes: hashes)).segments.first { !$0.filter.isEmpty }?.filter

        // Then
        guard case let .convolve(convolution)? = movingFilter?.first?.operations.first, case let .envelope(gain) = convolution.gain else {
            Issue.record("expected a convolve whose gain moves, got \(String(describing: movingFilter))")
            return
        }
        #expect(convolution.file == PinnedFile(path: "/abs/ding.wav", sha256: "ding-digest"))
        #expect(gain.first == EnvelopePoint(time: 0, value: -12))
        #expect(gain.first { $0.time == 1 }?.value == -6)
        #expect(gain.last?.value == 0)
        #expect(movingFilter?.first?.mix == .constant(1))
        #expect(heldFilter?.first?.operations == [
            .convolve(MixConvolution(file: PinnedFile(path: "/abs/ding.wav", sha256: "ding-digest"), gain: .constant(-6)))
        ])
    }

    @Test("a keyframe that writes a convolve's file stops, naming the keyframe")
    func refusesKeyframedImpulseResponse() throws {
        // When, Then
        #expect(throws: LookError.keyframedStatic(place: clip.appending(key: "keyframes").appending(index: 0).appending(key: "audioFilter").appending(key: "file"))) {
            try plan(#"""
                { "kind": "sequence", "storyline": [ { "kind": "media", "media": "/abs/run.mp4", "out": 4 } ],
                  "clips": [ { "kind": "media", "media": "/abs/bgm.m4a", "at": 0, "audioFilter": { "op": "convolve", "file": "/abs/ding.wav" },
                    "keyframes": [ { "at": 0, "audioFilter": { "file": "/abs/bgm.m4a" } } ] } ] }
                """#)
        }
    }

    // MARK: - Private
    @discardableResult
    private func plan(_ document: String) throws -> SequencePlan {
        try sut.plan(Fixture.planner.plan(document: Fixture.json(document)))
    }

    private func operation(
        of body: TimedValue,
        at time: Double
    ) -> SampledValue? {
        body.sampled(at: time, as: LookStructureTable.audioOperation("limiter"))
    }

    private func sampledLimiter(
        of filter: TimedValue,
        at time: Double
    ) -> SampledValue? {
        guard
            case let .list(entries) = filter.sampled(at: time, as: LookStructureTable.resolvedAudioFilter),
            let entry = entries.first,
            let operation = operation(of: entry),
            operation.name == "op:limiter"
        else {
            return nil
        }

        return operation.body
    }

    private func operation(of entry: SampledValue) -> (name: String, body: SampledValue)? {
        guard case let .list(operations) = entry["ops"], case let .form(name, body) = operations.first else { return nil }

        return (name, body)
    }

    // The file of the first op of a resolved audio filter's first entry.
    private func file(of filter: TimedValue) -> String? {
        guard
            case let .list(entries) = filter,
            case let .list(operations)? = entries.first?["ops"],
            case let .form(_, body)? = operations.first,
            case let .fixed(.string(path))? = body["file"]
        else {
            return nil
        }

        return path
    }

    private func band(
        of filter: TimedValue,
        at time: Double
    ) -> SampledValue? {
        guard
            case let .list(entries) = filter.sampled(at: time, as: LookStructureTable.resolvedAudioFilter),
            let entry = entries.first,
            let operation = operation(of: entry),
            case let .list(bands) = operation.body["bands"],
            case let .form(_, band) = bands.first
        else {
            return nil
        }

        return band
    }
}

//
//  SoundPlanTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

// `/abs/run.mp4` (30 seconds) and the audio files hold sound, `/abs/bgm.m4a` lasting 20 seconds and `/abs/ding.wav`
// 1.5. `/abs/short.mp4` is silent. `wipe-right` lasts 1 second and `flash` half a second.
@Suite("SoundPlan Tests")
struct SoundPlanTests {
    // MARK: - Property
    private let sut = Fixture.sequencePlanner

    // MARK: - Initializer
    // MARK: - Test
    @Test("a storyline clip with sound plays its drawn range at volume 1, from its in at its edit point")
    func plansDefaultVolume() throws {
        // Given
        let time = try Fixture.planner.plan(document: Fixture.json(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "in": 2, "out": 8 } ] }
            """#))
        let media = try #require(time.storyline[0].source.media)

        // When
        let plan = try sut.plan(time)

        // Then
        #expect(plan.sound == [
            SoundPlan(
                place: time.storyline[0].place,
                media: media,
                map: TimeMap(origin: 0, in: 2, speed: 1),
                out: 8,
                loop: false,
                range: TimeRange(start: 0, end: 6),
                audible: TimeRange(start: 0, end: 6),
                volume: .value(1),
                fadeIn: nil,
                fadeOut: nil,
                incoming: nil,
                outgoing: nil,
                nested: []
            )
        ])
    }

    @Test("clips without sound are left out: silent video, a still, a compound clip of a still, a title")
    func leavesOutSilentClips() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence",
              "storyline": [ { "media": "/abs/short.mp4", "connected": [ { "media": "/abs/short.mp4", "at": 0 } ] }, { "media": "/abs/card.png", "duration": 1 } ],
              "clips": [ { "media": { "kind": "sequence", "storyline": [ { "media": "/abs/card.png", "duration": 1 } ] }, "at": [0, 1] }, { "title": "a", "style": "subtitle", "at": [0, 1] } ] }
            """#)

        // Then
        #expect(plan.sound.isEmpty)
    }

    @Test("sound is in document order: each storyline clip, its connected clips, then the sequence clips")
    func ordersSound() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence",
              "storyline": [ { "media": "/abs/run.mp4", "out": 2, "connected": [ { "media": "/abs/ding.wav", "at": 0 } ] }, { "media": "/abs/run.mp4", "out": 2 } ],
              "clips": [ { "media": "/abs/bgm.m4a" } ] }
            """#)

        // Then
        #expect(plan.sound.map(\.place.description) == ["storyline[0]", "storyline[0].connected[0]", "storyline[1]", "clips[0]"])
    }

    @Test("volume keyframes move into sequence time, a storyline clip's through its map and a clip's through its clock")
    func movesVolumeKeyframes() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [
                { "media": "/abs/run.mp4", "out": 3 },
                { "media": "/abs/run.mp4", "in": 2, "out": 8, "speed": 2,
                  "keyframes": [ { "at": 4, "volume": 0.5 }, { "at": 6, "volume": 1 } ],
                  "connected": [ { "media": "/abs/bgm.m4a", "at": 3, "keyframes": [ { "at": 4, "volume": 0 }, { "at": 5, "volume": 1 } ] } ] } ] }
            """#)

        // Then
        #expect(plan.sound[1].volume == .keyframes([
            TimedValue(index: 0, at: 4, value: 0.5, ease: .linear),
            TimedValue(index: 1, at: 5, value: 1, ease: .linear)
        ]))
        #expect(plan.sound[2].range == TimeRange(start: 3.5, end: 6))
        #expect(plan.sound[2].volume == .keyframes([
            TimedValue(index: 0, at: 4, value: 0, ease: .linear),
            TimedValue(index: 1, at: 4.5, value: 1, ease: .linear)
        ]))
    }

    @Test("a static volume is kept")
    func keepsStaticVolume() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 2, "volume": 0.4 } ] }
            """#)

        // Then
        #expect(plan.sound[0].volume == .value(0.4))
    }

    @Test("fades lie at the ends of a storyline clip's drawn range and of a clip's visible window, so the sequence end moves a fade out")
    func placesFades() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence",
              "storyline": [
                { "media": "/abs/run.mp4", "out": 4, "fadeIn": 0.5 },
                { "media": "/abs/run.mp4", "in": 10, "out": 14, "transition": "frames/flash", "fadeOut": 1,
                  "connected": [ { "media": "/abs/ding.wav", "at": 11, "fadeIn": 0.25, "fadeOut": 0.5 } ] } ],
              "clips": [ { "media": "/abs/bgm.m4a", "at": 6, "fadeOut": 2 } ] }
            """#)

        // Then
        #expect(plan.sound.map(\.fadeIn) == [
            TimeRange(start: 0, end: 0.5),
            nil,
            TimeRange(start: 5, end: 5.25),
            nil
        ])
        #expect(plan.sound.map(\.fadeOut) == [
            nil,
            TimeRange(start: 7, end: 8),
            TimeRange(start: 6, end: 6.5),
            TimeRange(start: 6, end: 8)
        ])
        #expect(plan.sound[3].range == TimeRange(start: 6, end: 8))
    }

    @Test(
        "a clip past its out repeats when it loops and is silent when it does not",
        arguments: [("true", 4.0), ("false", 1.5)]
    )
    func plansLoop(
        loop: String,
        audibleEnd: Double
    ) throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 4 } ],
              "clips": [ { "media": "/abs/ding.wav", "at": [0, 4], "loop": \#(loop) } ] }
            """#)

        // Then
        #expect(plan.sound[1].loop == (loop == "true"))
        #expect(plan.sound[1].range == TimeRange(start: 0, end: 4))
        #expect(plan.sound[1].audible == TimeRange(start: 0, end: audibleEnd))
    }

    @Test("both clips of a transition with handles play across it and keep its range to crossfade over")
    func plansCrossfade() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [
                { "media": "/abs/run.mp4", "in": 2, "out": 6 },
                { "media": "/abs/run.mp4", "in": 10, "out": 14, "transition": "frames/wipe-right" } ] }
            """#)

        // Then
        let transition = TimeRange(start: 3.5, end: 4.5)
        #expect(plan.sound[0].range == TimeRange(start: 0, end: 4.5))
        #expect(plan.sound[0].audible == TimeRange(start: 0, end: 4.5))
        #expect(plan.sound[0].incoming == nil)
        #expect(plan.sound[0].outgoing == transition)
        #expect(plan.sound[1].range == TimeRange(start: 3.5, end: 8))
        #expect(plan.sound[1].audible == TimeRange(start: 3.5, end: 8))
        #expect(plan.sound[1].incoming == transition)
        #expect(plan.sound[1].outgoing == nil)
    }

    @Test("where a handle runs out of media its sound is silent")
    func silencesHandleWithoutMedia() throws {
        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [
                { "media": "/abs/run.mp4", "in": 26, "out": 30 },
                { "media": "/abs/run.mp4", "in": 0, "out": 4, "transition": "frames/wipe-right" } ] }
            """#)

        // Then
        #expect(plan.sound[0].range == TimeRange(start: 0, end: 4.5))
        #expect(plan.sound[0].audible == TimeRange(start: 0, end: 4))
        #expect(plan.sound[1].range == TimeRange(start: 3.5, end: 8))
        #expect(plan.sound[1].audible == TimeRange(start: 4, end: 8))
    }

    @Test("a compound clip has sound when its nested plan does, and carries the nested sounds on their own clock")
    func plansCompoundSound() throws {
        // Given
        let loud = #"{ "kind": "sequence", "storyline": [ { "media": "/abs/run.mp4", "out": 1 } ] }"#
        let silent = #"{ "kind": "sequence", "storyline": [ { "media": "/abs/short.mp4" } ] }"#

        // When
        let plan = try plan(#"""
            { "kind": "sequence", "storyline": [
                { "media": "/abs/short.mp4", "connected": [ { "media": \#(loud), "at": 0 }, { "media": \#(silent), "at": 0 } ] },
                { "media": \#(loud), "volume": 0.5 },
                { "media": \#(silent) } ] }
            """#)

        // Then
        #expect(plan.sound.map(\.place.description) == ["storyline[0].connected[0]", "storyline[1]"])
        #expect(plan.sound.map(\.media.hasSound) == [true, true])
        #expect(plan.sound[0].range == TimeRange(start: 0, end: 1))
        #expect(plan.sound[0].nested.map(\.range) == [TimeRange(start: 0, end: 1)])
        #expect(plan.sound[1].range == TimeRange(start: 4, end: 5))
        #expect(plan.sound[1].volume == .value(0.5))
        #expect(plan.sound[1].nested.map(\.range) == [TimeRange(start: 0, end: 1)])
    }

    // MARK: - Private
    private func plan(_ document: String) throws -> SequencePlan {
        try sut.plan(Fixture.planner.plan(document: Fixture.json(document)))
    }
}

//
//  MediaClockTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("MediaClock Tests")
struct MediaClockTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a media clip plays from in at the start of its window, at its own speed")
    func playsFromIn() {
        // Given
        let played = PlayedRange(map: TimeMap(origin: 10, in: 1, speed: 2), out: 3, loop: false)
        let sut = MediaClock(playback: .played(played), frames: 0...3)

        // When
        let time = sut.mediaTime(atSequenceTime: 10.5)

        // Then
        #expect(time == 2)
        #expect(played.naturalLength == 1)
    }

    @Test("past its out a video holds its last frame before out")
    func holdsPastOut() {
        // Given
        let played = PlayedRange(map: TimeMap(origin: 0, in: 0, speed: 1), out: 2, loop: false)
        let sut = MediaClock(playback: .played(played), frames: 0...3)

        // When
        let held = sut.mediaTime(atSequenceTime: 6)

        // Then
        #expect(held == 2 - .timeResolution)
    }

    @Test("a looping clip repeats from in to out to fill its window")
    func loopsFromInToOut() {
        // Given
        let played = PlayedRange(map: TimeMap(origin: 2, in: 0.5, speed: 1), out: 1.5, loop: true)
        let sut = MediaClock(playback: .played(played), frames: nil)

        // When
        let times = [2.25, 3.25, 4.75].map { sut.mediaTime(atSequenceTime: $0) }

        // Then
        #expect(times == [0.75, 0.75, 1.25])
    }

    @Test("at a seam reached through noisy sums a looping video repeats from in")
    func loopsAtNoisySeam() {
        // Given
        // 0.7 + 0.5 lands a hair past 1.2, a clip time a hair under `out` 0.3.
        let file = MediaFile(path: "/abs/ten.mp4", frameTimes: (0..<10).map { Double($0) / 10 })
        let played = PlayedRange(map: TimeMap(origin: 1, in: 0.1, speed: 1), out: 0.3, loop: true)
        let sut = MediaClock(playback: .played(played), frames: 0...0.9)

        // When
        let repeated = sut.mediaTime(atSequenceTime: 0.7 + 0.5)

        // Then
        #expect(file.frameIndex(at: repeated) == 1)
    }

    @Test("a looping sound on the sequence repeats through the window the plan gives it")
    func loopsSequenceSound() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 40 } ],
              "clips": [ { "media": "/abs/bgm.m4a", "loop": true }, { "at": [1, 5], "media": "/abs/ding.wav" } ] }
            """##)

        // When
        let plan = try Fixture.planner.plan(document: document)

        // Then
        #expect(plan.clips[0].mediaClock?.mediaTime(atSequenceTime: 25) == 5)
        #expect(plan.clips[1].mediaClock?.mediaTime(atSequenceTime: 2) == 1)
        #expect(plan.clips[1].window == TimeRange(start: 1, end: 5))
    }

    @Test("a connected compound clip lasts its nested sequence from a single start")
    func timesConnectedCompoundClip() throws {
        // Given
        let document = try Fixture.json(##"""
            { "kind": "sequence", "storyline": [ { "solid": "#000000", "duration": 10, "connected": [
              { "at": 1, "media": { "kind": "sequence", "storyline": [ { "solid": "#FFFFFF", "duration": 3 } ] } }
            ] } ] }
            """##)

        // When
        let plan = try Fixture.planner.plan(document: document)

        // Then
        #expect(plan.clips[0].kind == .media(.sequence))
        #expect(plan.clips[0].window == TimeRange(start: 1, end: 4))
        #expect(plan.clips[0].media?.sequence?.storyline[0].place.description == "storyline[0].connected[0].media.storyline[0]")
    }
}

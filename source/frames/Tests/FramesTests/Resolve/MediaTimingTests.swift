//
//  MediaTimingTests.swift
//  FramesTests
//
//  Created by JSilver on 11/15/26.
//

import Testing

@testable import Frames

@Suite("MediaTiming Tests")
struct MediaTimingTests {
    // MARK: - Property
    private let video = MediaPlan(
        kind: .video,
        reference: "/abs/short.mp4",
        source: .file(MediaFile(path: "/abs/short.mp4", fps: 1)),
        duration: 4,
        frames: 0...3
    )
    private let sound = MediaPlan(
        kind: .audio,
        reference: "/abs/ding.wav",
        source: .file(MediaFile(path: "/abs/ding.wav")),
        duration: 1.5
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test("a media clip plays from in at the start of its window, at its own speed")
    func playsFromIn() {
        // Given
        let sut = MediaTiming(media: video, map: TimeMap(origin: 10, in: 1, speed: 2), out: 3, loop: false)

        // When
        let time = sut.mediaTime(atSequenceTime: 10.5)

        // Then
        #expect(time == 2)
        #expect(sut.naturalLength == 1)
    }

    @Test("past its out a video holds its last frame and a sound goes silent")
    func holdsOrSilencesPastOut() {
        // Given
        let picture = MediaTiming(media: video, map: TimeMap(origin: 0, in: 0, speed: 1), out: 4, loop: false)
        let silent = MediaTiming(media: sound, map: TimeMap(origin: 0, in: 0, speed: 1), out: 1.5, loop: false)

        // When
        let held = picture.mediaTime(atSequenceTime: 6)
        let gone = silent.mediaTime(atSequenceTime: 2)

        // Then
        #expect(held == 3)
        #expect(gone == nil)
    }

    @Test("a looping clip repeats from in to out to fill its window")
    func loopsFromInToOut() {
        // Given
        let sut = MediaTiming(media: sound, map: TimeMap(origin: 2, in: 0.5, speed: 1), out: 1.5, loop: true)

        // When
        let times = [2.25, 3.25, 4.75].map { sut.mediaTime(atSequenceTime: $0) }

        // Then
        #expect(times == [0.75, 0.75, 1.25])
    }

    @Test("at a seam reached through noisy sums a looping video repeats from in, and a sound past out is silent")
    func loopsAtNoisySeam() {
        // Given
        // 0.7 + 0.5 lands a hair past 1.2, a clip time a hair under `out` 0.3.
        let file = MediaFile(path: "/abs/ten.mp4", frameTimes: (0..<10).map { Double($0) / 10 })
        let tenFrames = MediaPlan(
            kind: .video,
            reference: "/abs/ten.mp4",
            source: .file(file),
            duration: 1,
            frames: 0...0.9
        )
        let looping = MediaTiming(media: tenFrames, map: TimeMap(origin: 1, in: 0.1, speed: 1), out: 0.3, loop: true)
        let silent = MediaTiming(media: sound, map: TimeMap(origin: 1, in: 0.1, speed: 1), out: 0.3, loop: false)

        // When
        let repeated = looping.mediaTime(atSequenceTime: 0.7 + 0.5)
        let gone = silent.mediaTime(atSequenceTime: 0.7 + 0.5)

        // Then
        #expect(repeated.map(file.frameIndex(at:)) == 1)
        #expect(gone == nil)
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
        #expect(plan.clips[0].timing?.mediaTime(atSequenceTime: 25) == 5)
        #expect(plan.clips[1].timing?.mediaTime(atSequenceTime: 2) == 1)
        #expect(plan.clips[1].timing?.mediaTime(atSequenceTime: 3) == nil)
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

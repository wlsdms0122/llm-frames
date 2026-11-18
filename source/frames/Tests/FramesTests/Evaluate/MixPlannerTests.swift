//
//  MixPlannerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("MixPlanner Tests")
struct MixPlannerTests {
    // MARK: - Property
    private let sut = MixPlanner()
    private let music = PinnedMedia(source: .file(PinnedFile(path: "/abs/music.m4a", sha256: String(repeating: "a", count: 64))))
    private let voice = PinnedMedia(source: .file(PinnedFile(path: "/abs/voice.m4a", sha256: String(repeating: "b", count: 64))))

    // MARK: - Initializer
    // MARK: - Test
    @Test("a sound at a static volume is one segment at that gain, with a point at every frame time")
    func playsStaticVolume() {
        // Given
        let audio = [sound(music, in: 2, start: 0, end: 1, volume: [Keyframe(at: 0, value: 0.5)])]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 4, duration: 1))

        // Then
        #expect(plan.segments == [
            MixSegment(
                media: music,
                mediaStart: 2,
                speed: 1,
                start: 0,
                end: 1,
                envelope: envelope([[0, 0.5], [0.25, 0.5], [0.5, 0.5], [0.75, 0.5], [1, 0.5]])
            )
        ])
    }

    @Test("a sound whose `in` plays before it is heard starts at the media time its clock gives at its start")
    func startsOnItsClock() {
        // Given
        let audio = [sound(music, in: 2, origin: 0.5, speed: 2, start: 1, end: 1.5, volume: [Keyframe(at: 1, value: 1)])]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 2, duration: 2))

        // Then
        #expect(plan.segments == [
            MixSegment(
                media: music,
                mediaStart: 3,
                speed: 2,
                start: 1,
                end: 1.5,
                envelope: envelope([[1, 1], [1.5, 1]])
            )
        ])
    }

    @Test("keyframed volume is sampled with its ease at every frame time and at every keyframe")
    func samplesEasedVolume() throws {
        // Given
        let volume = [
            Keyframe(at: 0, value: 0.0, ease: .easeIn),
            Keyframe(at: 1, value: 1.0),
            Keyframe(at: 1.1, value: 0.5)
        ]
        let audio = [sound(music, start: 0, end: 1.5, volume: volume)]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 4, duration: 1.5))

        // Then
        let segment = try #require(plan.segments.first)
        #expect(plan.segments.count == 1)
        #expect(segment.envelope == envelope([
            [0, 0],
            [0.25, 0.015625],
            [0.5, 0.125],
            [0.75, 0.421875],
            [1, 1],
            [1.1, 0.5],
            [1.25, 0.5],
            [1.5, 0.5]
        ]))
    }

    @Test("a fade ramps the gain linearly from 0 over its range and to 0 over its range")
    func fadesInAndOut() throws {
        // Given
        let audio = [
            sound(
                music,
                start: 0,
                end: 2,
                fadeIn: TimeRange(start: 0, end: 0.25),
                fadeOut: TimeRange(start: 1, end: 2)
            )
        ]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 2, duration: 2))

        // Then
        let segment = try #require(plan.segments.first)
        #expect(segment.envelope == envelope([[0, 0], [0.25, 1], [0.5, 1], [1, 1], [1.5, 0.5], [2, 0]]))
    }

    @Test("over a transition the outgoing sound fades out and the incoming one fades in, in audio entry order")
    func crossfadesOverTransition() {
        // Given
        let transition = TimeRange(start: 1.5, end: 2.5)
        let audio = [
            sound(music, in: 0, start: 0, end: 2.5, outgoing: transition),
            sound(voice, in: 9.5, start: 1.5, end: 4, incoming: transition)
        ]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 2, duration: 4))

        // Then
        #expect(plan.segments == [
            MixSegment(
                media: music,
                mediaStart: 0,
                speed: 1,
                start: 0,
                end: 2.5,
                envelope: envelope([[0, 1], [0.5, 1], [1, 1], [1.5, 1], [2, 0.5], [2.5, 0]])
            ),
            MixSegment(
                media: voice,
                mediaStart: 9.5,
                speed: 1,
                start: 1.5,
                end: 4,
                envelope: envelope([[1.5, 0], [2, 0.5], [2.5, 1], [3, 1], [3.5, 1], [4, 1]])
            )
        ])
    }

    @Test("where a handle runs out of media the sound is silent, so its segment ends where its media does")
    func endsWhereHandleRunsOut() {
        // Given
        let audio = [
            sound(
                music,
                in: 8,
                start: 0,
                end: 2.5,
                audible: TimeRange(start: 0, end: 2),
                outgoing: TimeRange(start: 1.5, end: 2.5)
            )
        ]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 2, duration: 2.5))

        // Then
        #expect(plan.segments == [
            MixSegment(
                media: music,
                mediaStart: 8,
                speed: 1,
                start: 0,
                end: 2,
                envelope: envelope([[0, 1], [0.5, 1], [1, 1], [1.5, 1], [2, 0.5]])
            )
        ])
    }

    @Test("a loop is one segment per repeat from `in`, each starting where the last ends, the last cut where the sound ends")
    func repeatsLoop() {
        // Given
        let audio = [sound(music, in: 1, out: 3, speed: 2, loop: true, start: 0, end: 2.5)]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 2, duration: 2.5))

        // Then
        #expect(plan.segments == [
            MixSegment(media: music, mediaStart: 1, speed: 2, start: 0, end: 1, envelope: envelope([[0, 1], [0.5, 1], [1, 1]])),
            MixSegment(media: music, mediaStart: 1, speed: 2, start: 1, end: 2, envelope: envelope([[1, 1], [1.5, 1], [2, 1]])),
            MixSegment(media: music, mediaStart: 1, speed: 2, start: 2, end: 2.5, envelope: envelope([[2, 1], [2.5, 1]]))
        ])
    }

    @Test("a compound clip's sound is mapped through its clock and its gain multiplied by the compound clip's")
    func mapsNestedSound() {
        // Given
        let nested = sound(music, in: 0, start: 10, end: 14, fadeIn: TimeRange(start: 10, end: 11))
        let audio = [
            sound(nil, nested: [nested], in: 10, speed: 2, start: 1, end: 3, volume: [Keyframe(at: 1, value: 0.5)])
        ]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 4, duration: 3))

        // Then
        #expect(plan.segments == [
            MixSegment(
                media: music,
                mediaStart: 0,
                speed: 2,
                start: 1,
                end: 3,
                envelope: envelope([
                    [1, 0],
                    [1.25, 0.25],
                    [1.5, 0.5],
                    [1.75, 0.5],
                    [2, 0.5],
                    [2.25, 0.5],
                    [2.5, 0.5],
                    [2.75, 0.5],
                    [3, 0.5]
                ])
            )
        ])
    }

    @Test("a nested sound that starts before its compound clip is heard is cut to where the compound clip is heard")
    func cutsNestedSoundToOuter() {
        // Given
        let nested = sound(music, in: 5, start: 0, end: 2, fadeIn: TimeRange(start: 0, end: 2))
        let audio = [sound(nil, nested: [nested], in: 1, start: 3, end: 4)]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 2, duration: 4))

        // Then
        #expect(plan.segments == [
            MixSegment(
                media: music,
                mediaStart: 6,
                speed: 1,
                start: 3,
                end: 4,
                envelope: envelope([[3, 0.5], [3.5, 0.75], [4, 1]])
            )
        ])
    }

    @Test("a looping compound clip plays its sounds again in every repeat, each sound's segments together in time order")
    func repeatsNestedSounds() {
        // Given
        let nested = [
            sound(music, start: 0.5, end: 1),
            sound(voice, start: 0, end: 0.25)
        ]
        let audio = [sound(nil, nested: nested, out: 1, loop: true, start: 0, end: 2.5)]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 4, duration: 2.5))

        // Then
        #expect(plan.segments == [
            MixSegment(media: music, mediaStart: 0, speed: 1, start: 0.5, end: 1, envelope: envelope([[0.5, 1], [0.75, 1], [1, 1]])),
            MixSegment(media: music, mediaStart: 0, speed: 1, start: 1.5, end: 2, envelope: envelope([[1.5, 1], [1.75, 1], [2, 1]])),
            MixSegment(media: voice, mediaStart: 0, speed: 1, start: 0, end: 0.25, envelope: envelope([[0, 1], [0.25, 1]])),
            MixSegment(media: voice, mediaStart: 0, speed: 1, start: 1, end: 1.25, envelope: envelope([[1, 1], [1.25, 1]])),
            MixSegment(media: voice, mediaStart: 0, speed: 1, start: 2, end: 2.25, envelope: envelope([[2, 1], [2.25, 1]]))
        ])
    }

    // MARK: - Private
    // A sound heard over its whole range at volume 1 unless told otherwise.
    private func sound(
        _ media: PinnedMedia?,
        nested: [ResolvedSound] = [],
        in: Double = 0,
        origin: Double? = nil,
        out: Double = 100,
        speed: Double = 1,
        loop: Bool = false,
        start: Double,
        end: Double,
        audible: TimeRange? = nil,
        volume: [Keyframe<Double>]? = nil,
        fadeIn: TimeRange? = nil,
        fadeOut: TimeRange? = nil,
        incoming: TimeRange? = nil,
        outgoing: TimeRange? = nil
    ) -> ResolvedSound {
        ResolvedSound(
            place: "sound",
            media: media,
            nested: nested,
            played: PlayedRange(
                map: TimeMap(origin: origin ?? start, in: `in`, speed: speed),
                out: out,
                loop: loop
            ),
            start: start,
            end: end,
            audible: audible ?? TimeRange(start: start, end: end),
            volume: volume ?? [Keyframe(at: start, value: 1)],
            fadeIn: fadeIn,
            fadeOut: fadeOut,
            incoming: incoming,
            outgoing: outgoing
        )
    }

    private func sequence(
        _ audio: [ResolvedSound],
        fps: Double,
        duration: Double
    ) -> ResolvedSequence {
        ResolvedSequence(
            format: ResolvedFormat(
                size: Size(width: 1920, height: 1080),
                fps: fps,
                duration: duration,
                background: Color(written: "#000000"),
                conform: .fit
            ),
            storyline: [],
            clips: [],
            audio: audio
        )
    }

    // Points written as `[time, gain]`.
    private func envelope(_ points: [[Double]]) -> [EnvelopePoint] {
        points.map { EnvelopePoint(time: $0[0], gain: $0[1]) }
    }
}

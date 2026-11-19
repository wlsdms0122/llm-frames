//
//  MixPlannerTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Foundation
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
    @Test("a segment carries its sound's audio filter: a held leaf as a number, a moving frequency sampled in log space")
    func carriesAudioFilter() throws {
        // Given
        let band = TimedValue.form("type:peak", .object([
            TimedMember(key: "frequency", value: .track([
                Keyframe(at: 0, value: .number(100)),
                Keyframe(at: 2, value: .number(10000))
            ])),
            TimedMember(key: "gain", value: .track([Keyframe(at: 0, value: .number(6))])),
            TimedMember(key: "q", value: .track([Keyframe(at: 0, value: .number(0.7071))]))
        ]))
        let entry = TimedValue.object([
            TimedMember(key: "ops", value: .list([.form("op:eq", .object([TimedMember(key: "bands", value: .list([band]))]))])),
            TimedMember(key: "mix", value: .track([Keyframe(at: 0, value: .number(1))]))
        ])
        let audio = [sound(music, start: 0, end: 2, audioFilter: .list([entry]))]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 4, duration: 2))

        // Then
        let filter = try #require(plan.segments.first?.filter)
        #expect(filter.count == 1)
        #expect(filter[0].mix == .constant(1))
        guard case let .eq(bands) = filter[0].operations.first, case let .envelope(points) = bands.first?.frequency else {
            Issue.record("expected an eq band with a frequency envelope, got \(filter)")
            return
        }
        #expect(bands[0].type == .peak)
        #expect(bands[0].gain == .constant(6))
        #expect(bands[0].q == .constant(0.7071))
        #expect(points.map(\.time) == [0, 0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2])
        let middle = try #require(points.first { $0.time == 1 })
        #expect(abs(middle.value - 1000) < 1e-9)
    }

    @Test("a sound at a static volume is one segment at that gain, centred, with points only at its ends")
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
                envelope: envelope([[0, 0.5], [1, 0.5]]),
                pan: envelope([[0, 0], [1, 0]])
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
                envelope: envelope([[1, 1], [1.5, 1]]),
                pan: envelope([[1, 0], [1.5, 0]])
            )
        ])
    }

    @Test("keyframed volume is sampled with its ease at every frame time where it moves and at every keyframe")
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
        #expect(segment.envelope == envelope([[0, 0], [0.25, 1], [1, 1], [1.5, 0.5], [2, 0]]))
    }

    @Test("a looping sound a split starts before its origin plays the media before `in` and its first repeat as one segment")
    func playsLeadOfLoop() {
        // Given
        let audio = [sound(music, in: 2, origin: 3, out: 4, loop: true, start: 2, end: 6, audible: TimeRange(start: 2, end: 6))]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 2, duration: 6))

        // Then
        // The media runs on at `in`, so the filters keep their state there and start afresh at 5, where it jumps.
        #expect(plan.segments.map { [$0.start, $0.end, $0.mediaStart] } == [[2, 5, 1], [5, 6, 2]])
    }

    @Test("over a constant-gain transition the outgoing sound fades out and the incoming one in linearly, in entry order")
    func crossfadesOverTransition() {
        // Given
        let transition = Crossfade(range: TimeRange(start: 1.5, end: 2.5), curve: .constantGain)
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
                envelope: envelope([[0, 1], [1.5, 1], [2, 0.5], [2.5, 0]]),
                pan: envelope([[0, 0], [2.5, 0]])
            ),
            MixSegment(
                media: voice,
                mediaStart: 9.5,
                speed: 1,
                start: 1.5,
                end: 4,
                envelope: envelope([[1.5, 0], [2, 0.5], [2.5, 1], [4, 1]]),
                pan: envelope([[1.5, 0], [4, 0]])
            )
        ])
    }

    @Test("over a constant-power transition the outgoing gain is cos(uπ/2) and the incoming sin(uπ/2), u at an even pace")
    func crossfadesAtConstantPower() throws {
        // Given
        let transition = Crossfade(range: TimeRange(start: 1, end: 2), curve: .constantPower)
        let audio = [
            sound(music, start: 0, end: 2, outgoing: transition),
            sound(voice, start: 1, end: 3, incoming: transition)
        ]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 4, duration: 3))

        // Then
        let outgoing = try #require(plan.segments.first).envelope
        let incoming = try #require(plan.segments.last).envelope
        let progress = [0, 0.25, 0.5, 0.75, 1.0]
        #expect(outgoing.map(\.time) == [0] + progress.map { 1 + $0 })
        #expect(incoming.map(\.time) == progress.map { 1 + $0 } + [3])
        for (index, u) in progress.enumerated() {
            #expect(abs(outgoing[index + 1].value - cos(u * .pi / 2)) < 1e-12)
            #expect(abs(incoming[index].value - sin(u * .pi / 2)) < 1e-12)
            #expect(abs(pow(outgoing[index + 1].value, 2) + pow(incoming[index].value, 2) - 1) < 1e-12)
        }
    }

    @Test("volume, a fade and a crossfade multiply into one gain")
    func multipliesGains() throws {
        // Given
        let audio = [
            sound(
                music,
                start: 0,
                end: 2,
                volume: [Keyframe(at: 0, value: 0.5)],
                fadeOut: TimeRange(start: 1.5, end: 2),
                outgoing: Crossfade(range: TimeRange(start: 1, end: 2), curve: .constantGain)
            )
        ]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 2, duration: 2))

        // Then
        let segment = try #require(plan.segments.first)
        #expect(segment.envelope == envelope([[0, 0.5], [1, 0.5], [1.5, 0.25], [2, 0]]))
    }

    @Test("an eased pan key and a constant-power crossfade have a point at every frame over their spans and none outside")
    func samplesOnlyWhereMoving() throws {
        // Given
        let pan = [Keyframe(at: 2.5, value: -1.0, ease: .easeInOut), Keyframe(at: 3, value: 1.0)]
        let transition = Crossfade(range: TimeRange(start: 1, end: 2), curve: .constantPower)
        let audio = [sound(music, start: 0, end: 4, pan: pan, outgoing: transition)]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 4, duration: 4))

        // Then
        let segment = try #require(plan.segments.first)
        #expect(segment.envelope.map(\.time) == [0, 1, 1.25, 1.5, 1.75, 2, 4])
        #expect(segment.pan == envelope([[0, -1], [2.5, -1], [2.75, 0], [3, 1], [4, 1]]))
    }

    @Test("keyframed pan is sampled with its ease at every frame time where it moves")
    func samplesEasedPan() throws {
        // Given
        let pan = [Keyframe(at: 0, value: -1.0, ease: .easeIn), Keyframe(at: 1, value: 1.0)]
        let audio = [sound(music, start: 0, end: 1.5, pan: pan)]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 4, duration: 1.5))

        // Then
        let segment = try #require(plan.segments.first)
        #expect(segment.pan == envelope([[0, -1], [0.25, -0.96875], [0.5, -0.75], [0.75, -0.15625], [1, 1], [1.5, 1]]))
        #expect(segment.envelope == envelope([[0, 1], [1.5, 1]]))
    }

    @Test("a compound clip's pan is added to its sounds', the sum cut to -1 and 1")
    func addsNestedPan() throws {
        // Given
        let nested = sound(music, start: 0, end: 1, pan: [Keyframe(at: 0, value: -1.0), Keyframe(at: 1, value: 1.0)])
        let audio = [sound(nil, nested: [nested], start: 0, end: 1, pan: [Keyframe(at: 0, value: 0.5)])]

        // When
        let plan = sut.mix(of: sequence(audio, fps: 4, duration: 1))

        // Then
        let segment = try #require(plan.segments.first)
        #expect(segment.pan == envelope([[0, -0.5], [0.25, 0], [0.5, 0.5], [0.75, 1], [1, 1]]))
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
                outgoing: Crossfade(range: TimeRange(start: 1.5, end: 2.5), curve: .constantGain)
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
                envelope: envelope([[0, 1], [1.5, 1], [2, 0.5]]),
                pan: envelope([[0, 0], [2, 0]])
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
            segment(music, mediaStart: 1, speed: 2, start: 0, end: 1),
            segment(music, mediaStart: 1, speed: 2, start: 1, end: 2),
            segment(music, mediaStart: 1, speed: 2, start: 2, end: 2.5)
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
                envelope: envelope([[1, 0], [1.25, 0.25], [1.5, 0.5], [3, 0.5]]),
                pan: envelope([[1, 0], [3, 0]])
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
                envelope: envelope([[3, 0.5], [3.5, 0.75], [4, 1]]),
                pan: envelope([[3, 0], [4, 0]])
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
            segment(music, mediaStart: 0, speed: 1, start: 0.5, end: 1),
            segment(music, mediaStart: 0, speed: 1, start: 1.5, end: 2),
            segment(voice, mediaStart: 0, speed: 1, start: 0, end: 0.25),
            segment(voice, mediaStart: 0, speed: 1, start: 1, end: 1.25),
            segment(voice, mediaStart: 0, speed: 1, start: 2, end: 2.25)
        ])
    }

    // MARK: - Private
    // A sound heard over its whole range at volume 1 and centred unless told otherwise.
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
        pan: [Keyframe<Double>]? = nil,
        fadeIn: TimeRange? = nil,
        fadeOut: TimeRange? = nil,
        incoming: Crossfade? = nil,
        outgoing: Crossfade? = nil,
        audioFilter: TimedValue = .off
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
            pan: pan ?? [Keyframe(at: start, value: 0)],
            fadeIn: fadeIn,
            fadeOut: fadeOut,
            incoming: incoming,
            outgoing: outgoing,
            audioFilter: audioFilter
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

    // A segment at gain 1 and centred, its envelopes with points only at its ends.
    private func segment(
        _ media: PinnedMedia,
        mediaStart: Double,
        speed: Double,
        start: Double,
        end: Double
    ) -> MixSegment {
        MixSegment(
            media: media,
            mediaStart: mediaStart,
            speed: speed,
            start: start,
            end: end,
            envelope: envelope([[start, 1], [end, 1]]),
            pan: envelope([[start, 0], [end, 0]])
        )
    }

    // Points written as `[time, value]`.
    private func envelope(_ points: [[Double]]) -> [EnvelopePoint] {
        points.map { EnvelopePoint(time: $0[0], value: $0[1]) }
    }
}

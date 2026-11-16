//
//  AVFoundationMixerTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/16/26.
//

import Foundation
@testable import Frames
@testable import FramesAVFoundation
import FramesTestMedia
import Testing

// Serialized, since AVAssetReader needs a free thread of the shared pool, which tests reading sound at once can all
// hold.
@Suite("AVFoundationMixer Tests", .serialized)
struct AVFoundationMixerTests {
    // MARK: - Property
    // The channel of a 5.1 file that alone holds the tone, and the gains it reaches the left and right outputs at.
    private static let surroundGains: [(Int, Float, Float)] = [
        (0, 1, 0),
        (1, 0, 1),
        (2, 0.7071, 0.7071),
        (3, 0, 0),
        (4, 0.7071, 0),
        (5, 0, 0.7071)
    ]

    // 16 bit rounding of the written tone, and of a gain applied after it.
    private let tolerance: Float = 2.0 / 32_768
    private let rate = 48_000

    // MARK: - Initializer
    // MARK: - Test
    @Test("a mono source plays at the same level on both channels")
    func playsMonoOnBoth() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        let writer = SoundWriter(end: 1, levels: [0.25])
        try await writer.write(to: file)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(MixPlan(segments: [segment(of: file, from: 0, to: 1)]), duration: 1)

        // Then
        #expect(mixed.sampleRate == 48_000 && mixed.channels == 2)
        #expect(deviation(of: mixed, channel: 0, from: writer, sourceChannel: 0, frames: 0..<rate) < tolerance)
        #expect(deviation(of: mixed, channel: 1, from: writer, sourceChannel: 0, frames: 0..<rate) < tolerance)
    }

    @Test("a stereo source plays each channel on its own side")
    func passesStereo() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("stereo.wav")
        let writer = SoundWriter(end: 1, levels: [0.25, 0.1])
        try await writer.write(to: file)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(MixPlan(segments: [segment(of: file, from: 0, to: 1)]), duration: 1)

        // Then
        #expect(deviation(of: mixed, channel: 0, from: writer, sourceChannel: 0, frames: 0..<rate) < tolerance)
        #expect(deviation(of: mixed, channel: 1, from: writer, sourceChannel: 1, frames: 0..<rate) < tolerance)
    }

    @Test("a 5.1 source is downmixed by ITU-R BS.775, its low frequency effects dropped", arguments: surroundGains)
    func downmixesSurround(
        channel: Int,
        left: Float,
        right: Float
    ) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("surround.wav")
        let levels = (0..<6).map { $0 == channel ? 0.25 : 0 }
        let writer = SoundWriter(end: 1, levels: levels)
        try await writer.write(to: file)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(MixPlan(segments: [segment(of: file, from: 0, to: 1)]), duration: 1)

        // Then
        let leftDeviation = deviation(
            of: mixed,
            channel: 0,
            from: writer,
            sourceChannel: channel,
            gain: left,
            frames: 0..<rate
        )
        let rightDeviation = deviation(
            of: mixed,
            channel: 1,
            from: writer,
            sourceChannel: channel,
            gain: right,
            frames: 0..<rate
        )
        #expect(leftDeviation < tolerance && rightDeviation < tolerance, "\(leftDeviation) \(rightDeviation)")
    }

    @Test("an AAC 5.1 source's centre reaches both sides at 0.7071 of its level")
    func downmixesAACCentre() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("surround.m4a")
        try await SoundWriter(end: 1, levels: [0, 0, 0.25, 0, 0, 0]).write(to: file)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(MixPlan(segments: [segment(of: file, from: 0, to: 1)]), duration: 1)

        // Then
        let middle = 12_000..<36_000
        #expect(abs(peak(of: mixed, channel: 0, frames: middle) - 0.25 * 0.7071) < 0.01)
        #expect(abs(peak(of: mixed, channel: 1, frames: middle) - 0.25 * 0.7071) < 0.01)
    }

    @Test("a 44.1 kHz source is resampled to 48 kHz, keeping its tone's frequency, phase and length")
    func resamples() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("cd.wav")
        try await SoundWriter(end: 1, sampleRate: 44_100, levels: [0.25]).write(to: file)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())
        let expected = SoundWriter(end: 1, levels: [0.25])

        // When
        let mixed = try sut.mix(MixPlan(segments: [segment(of: file, from: 0, to: 1.5)]), duration: 1.5)

        // Then
        #expect(abs(crossings(of: mixed, frames: 4_800..<43_200) - 704) <= 1)
        #expect(deviation(of: mixed, channel: 0, from: expected, sourceChannel: 0, frames: 4_800..<43_200) < 0.002)
        #expect(peak(of: mixed, channel: 0, frames: 47_000..<47_900) > 0.2)
        #expect(peak(of: mixed, channel: 0, frames: 48_100..<72_000) < 0.002)
    }

    @Test("the envelope ramps the gain in straight lines between its points")
    func rampsEnvelope() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        let writer = SoundWriter(end: 1, levels: [0.25])
        try await writer.write(to: file)
        let ramp = [EnvelopePoint(time: 0, gain: 0), EnvelopePoint(time: 1, gain: 1)]
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(MixPlan(segments: [segment(of: file, from: 0, to: 1, envelope: ramp)]), duration: 1)

        // Then
        let middle = 23_900..<24_100
        let largest = middle.max { abs(writer.sample(channel: 0, at: $0)) < abs(writer.sample(channel: 0, at: $1)) }!
        let gain = mixed.samples[largest * 2] / Float(writer.sample(channel: 0, at: largest))
        #expect(abs(gain - Float(largest) / 48_000) < 0.001, "\(gain)")
    }

    @Test("two segments that overlap are summed, unclipped")
    func sumsOverlap() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        let writer = SoundWriter(end: 2, levels: [0.5])
        try await writer.write(to: file)
        let plan = MixPlan(segments: [
            segment(of: file, from: 0, to: 1),
            segment(of: file, mediaStart: 0.5, from: 0.5, to: 1.5)
        ])
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(plan, duration: 1.5)

        // Then
        #expect(deviation(of: mixed, channel: 0, from: writer, sourceChannel: 0, frames: 0..<24_000) < tolerance)
        #expect(
            deviation(of: mixed, channel: 0, from: writer, sourceChannel: 0, gain: 2, frames: 24_000..<48_000)
                < 2 * tolerance
        )
        #expect(peak(of: mixed, channel: 0, frames: 24_000..<48_000) > 0.99)
    }

    @Test("a segment is added into the output from the sample at its start")
    func placesAtStart() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        let writer = SoundWriter(end: 1, levels: [0.25])
        try await writer.write(to: file)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(MixPlan(segments: [segment(of: file, from: 0.25, to: 0.75)]), duration: 1)

        // Then
        let placed = (12_000..<36_000).map { frame in
            abs(mixed.samples[frame * 2] - Float(writer.sample(channel: 0, at: frame - 12_000)))
        }
        #expect(placed.max()! < tolerance)
        #expect(peak(of: mixed, channel: 0, frames: 0..<12_000) == 0)
        #expect(peak(of: mixed, channel: 0, frames: 36_000..<48_000) == 0)
    }

    @Test("at speed 2 a source plays in half its length with its tone's frequency kept")
    func stretchesWithPitchKept() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        try await SoundWriter(end: 2, levels: [0.25]).write(to: file)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(MixPlan(segments: [segment(of: file, speed: 2, from: 0, to: 1.5)]), duration: 1.5)

        // Then
        let frames = 9_600..<38_400
        let frequency = Double(crossings(of: mixed, frames: frames)) / 2 / (Double(frames.count) / 48_000)
        #expect(abs(frequency - 440) / 440 < 0.02, "\(frequency)")
        #expect(peak(of: mixed, channel: 0, frames: 46_000..<47_500) > 0.1)
        #expect(peak(of: mixed, channel: 0, frames: 48_000..<72_000) == 0)
    }

    @Test("the output is 48 kHz stereo of round(duration × 48000) frames", arguments: [1, 0.5, 1.0 / 3, 2.000_01])
    func lastsDuration(duration: Double) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        try await SoundWriter(end: 3, levels: [0.25]).write(to: file)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(MixPlan(segments: [segment(of: file, from: 0, to: 3)]), duration: duration)

        // Then
        #expect(mixed.sampleRate == 48_000 && mixed.channels == 2)
        #expect(mixed.frameCount == Int((duration * 48_000).rounded()))
    }

    @Test("checking a plan refuses a segment whose file has no sound track, naming the segment and the file")
    func refusesSilentFile() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let sound = directory.file("mono.wav")
        let video = directory.file("silent.mov")
        try await SoundWriter(end: 1).write(to: sound)
        try await FramesTestMedia.VideoWriter(size: Size(width: 64, height: 64), frameTimes: [0], end: 1)
            .write(to: video) { _, _ in }
        let plan = MixPlan(segments: [segment(of: sound, from: 0, to: 1), segment(of: video, from: 0, to: 1)])
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let error = #expect(throws: MixerError.self) { try sut.check(plan) }

        // Then
        #expect(error?.description == "mix plan segments[1]: media \(video) has no sound track")
    }

    @Test("checking a plan refuses a speed the time stretch does not reach, and passes one it does")
    func refusesUnstretchableSpeed() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        try await SoundWriter(end: 1).write(to: file)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let error = #expect(throws: MixerError.self) {
            try sut.check(MixPlan(segments: [segment(of: file, speed: 64, from: 0, to: 0.01)]))
        }

        // Then
        #expect(
            error?.description == "mix plan segments[0]: media \(file) plays at speed 64.0, outside the 1/32 to 32 its "
                + "time stretch keeps the pitch over"
        )
        #expect(throws: Never.self) {
            try sut.check(MixPlan(segments: [segment(of: file, speed: 0.5, from: 0, to: 1)]))
        }
    }

    // MARK: - Private
    private func segment(
        of file: String,
        mediaStart: Double = 0,
        speed: Double = 1,
        from start: Double,
        to end: Double,
        envelope: [EnvelopePoint]? = nil
    ) -> MixSegment {
        MixSegment(
            media: PinnedMedia(source: .file(PinnedFile(path: file, sha256: ""))),
            mediaStart: mediaStart,
            speed: speed,
            start: start,
            end: end,
            envelope: envelope ?? [EnvelopePoint(time: start, gain: 1), EnvelopePoint(time: end, gain: 1)]
        )
    }

    // The largest difference over `frames` between an output channel and the written tone's channel times `gain`.
    private func deviation(
        of mixed: SoundBuffer,
        channel: Int,
        from writer: SoundWriter,
        sourceChannel: Int,
        gain: Float = 1,
        frames: Range<Int>
    ) -> Float {
        frames.map { frame in
            abs(mixed.samples[frame * 2 + channel] - gain * Float(writer.sample(channel: sourceChannel, at: frame)))
        }.max() ?? 0
    }

    private func peak(
        of mixed: SoundBuffer,
        channel: Int,
        frames: Range<Int>
    ) -> Float {
        frames.map { abs(mixed.samples[$0 * 2 + channel]) }.max() ?? 0
    }

    // The times the left channel changes sign over `frames`.
    private func crossings(
        of mixed: SoundBuffer,
        frames: Range<Int>
    ) -> Int {
        zip(frames.dropLast(), frames.dropFirst()).count { previous, next in
            (mixed.samples[previous * 2] < 0) != (mixed.samples[next * 2] < 0)
        }
    }
}

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

    // Which sounds a crossfade joins (two unrelated noises, or two copies of one tone, a cut inside one take), its curve,
    // and the level of its middle against its ends in dB: held by the curve that suits the pair, a 3 dB swell or dip by
    // the other.
    private static let crossfadeLevels: [(Bool, CrossfadeCurve, Double)] = [
        (false, .constantPower, 0),
        (true, .constantGain, 0),
        (true, .constantPower, 3.0103),
        (false, .constantGain, -3.0103)
    ]

    // A compressor that takes a tone at -6 dBFS down by about 9 dB within a few milliseconds and lets it go slowly.
    private static let compressorFilter = [
        MixFilterEntry(
            operations: [
                .compressor(MixCompressor(
                    threshold: .constant(-18),
                    ratio: .constant(4),
                    knee: .constant(0),
                    attack: .constant(0.002),
                    release: .constant(0.5),
                    makeup: .constant(0)
                ))
            ],
            mix: .constant(1)
        )
    ]

    // 16 bit rounding of the written tone, and of a gain applied after it.
    private let tolerance: Float = 2.0 / 32_768
    private let rate = 48_000
    // Each channel's gain for a mono source at the centre.
    private let centre = Float(cos(Double.pi / 4))

    // MARK: - Initializer
    // MARK: - Test
    @Test("a mono source at the centre plays at the same level on both channels, cos(π/4) of its own")
    func playsMonoOnBoth() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        let writer = SoundWriter(end: 1, levels: [0.25])
        try await writer.write(to: file)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(MixPlan(length: 48000, segments: [segment(of: file, from: 0, to: 1)]))

        // Then
        #expect(mixed.sampleRate == 48_000 && mixed.channels == 2)
        #expect(deviation(of: mixed, channel: 0, from: writer, sourceChannel: 0, gain: centre, frames: 0..<rate) < tolerance)
        #expect(deviation(of: mixed, channel: 1, from: writer, sourceChannel: 0, gain: centre, frames: 0..<rate) < tolerance)
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
        let mixed = try sut.mix(MixPlan(length: 48000, segments: [segment(of: file, from: 0, to: 1)]))

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
        let mixed = try sut.mix(MixPlan(length: 48000, segments: [segment(of: file, from: 0, to: 1)]))

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
        let mixed = try sut.mix(MixPlan(length: 48000, segments: [segment(of: file, from: 0, to: 1)]))

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
        let mixed = try sut.mix(MixPlan(length: 72000, segments: [segment(of: file, from: 0, to: 1.5)]))

        // Then
        #expect(abs(crossings(of: mixed, frames: 4_800..<43_200) - 704) <= 1)
        #expect(
            deviation(of: mixed, channel: 0, from: expected, sourceChannel: 0, gain: centre, frames: 4_800..<43_200)
                < 0.002
        )
        #expect(peak(of: mixed, channel: 0, frames: 47_000..<47_900) > 0.15)
        #expect(peak(of: mixed, channel: 0, frames: 48_100..<72_000) < 0.002)
    }

    @Test("the envelope ramps the gain in straight lines between its points")
    func rampsEnvelope() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        let writer = SoundWriter(end: 1, levels: [0.25])
        try await writer.write(to: file)
        let ramp = [EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: 1, value: 1)]
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(MixPlan(length: 48000, segments: [segment(of: file, from: 0, to: 1, envelope: ramp)]))

        // Then
        let middle = 23_900..<24_100
        let largest = middle.max { abs(writer.sample(channel: 0, at: $0)) < abs(writer.sample(channel: 0, at: $1)) }!
        let gain = mixed.samples[largest * 2] / Float(writer.sample(channel: 0, at: largest)) / centre
        #expect(abs(gain - Float(largest) / 48_000) < 0.001, "\(gain)")
    }

    @Test("two segments that overlap are summed, unclipped")
    func sumsOverlap() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        let writer = SoundWriter(end: 2, levels: [0.75])
        try await writer.write(to: file)
        let plan = MixPlan(length: 72000, segments: [
            segment(of: file, from: 0, to: 1),
            segment(of: file, mediaStart: 0.5, from: 0.5, to: 1.5)
        ])
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(plan)

        // Then
        #expect(
            deviation(of: mixed, channel: 0, from: writer, sourceChannel: 0, gain: centre, frames: 0..<24_000)
                < tolerance
        )
        #expect(
            deviation(of: mixed, channel: 0, from: writer, sourceChannel: 0, gain: 2 * centre, frames: 24_000..<48_000)
                < 2 * tolerance
        )
        #expect(peak(of: mixed, channel: 0, frames: 24_000..<48_000) > 1)
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
        let mixed = try sut.mix(MixPlan(length: 48000, segments: [segment(of: file, from: 0.25, to: 0.75)]))

        // Then
        let placed = (12_000..<36_000).map { frame in
            abs(mixed.samples[frame * 2] - centre * Float(writer.sample(channel: 0, at: frame - 12_000)))
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
        let mixed = try sut.mix(MixPlan(length: 72000, segments: [segment(of: file, speed: 2, from: 0, to: 1.5)]))

        // Then
        let frames = 9_600..<38_400
        let frequency = Double(crossings(of: mixed, frames: frames)) / 2 / (Double(frames.count) / 48_000)
        #expect(abs(frequency - 440) / 440 < 0.02, "\(frequency)")
        #expect(peak(of: mixed, channel: 0, frames: 46_000..<47_500) > 0.1)
        #expect(peak(of: mixed, channel: 0, frames: 48_000..<72_000) == 0)
    }

    @Test("the output is 48 kHz stereo of the plan's length, from sequence time 0", arguments: [48_000, 24_000, 16_000, 96_001])
    func lastsLength(length: Int) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        try await SoundWriter(end: 3, levels: [0.25]).write(to: file)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(MixPlan(length: length, segments: [segment(of: file, from: 0, to: 3)]))

        // Then
        #expect(mixed.sampleRate == 48_000 && mixed.channels == 2)
        #expect(mixed.frameCount == length)
    }

    @Test("a mono noise panned left, centre and right keeps its power, each channel 3.01 dB down at the centre")
    func keepsMonoPowerAcrossPan() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("noise.wav")
        try await SoundWriter(end: 1, signal: .noise(seed: 1), levels: [0.25]).write(to: file)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())
        let unpanned = try decoded(file)

        // When
        let mixed = try [-1.0, 0, 1].map { pan in
            try sut.mix(MixPlan(length: 48000, segments: [segment(of: file, from: 0, to: 1, pan: pan)]))
        }

        // Then
        let source = power(of: unpanned.samples)
        let totals = mixed.map { decibels(power(of: $0, channel: 0) + power(of: $0, channel: 1), against: source) }
        let centre = [0, 1].map { decibels(power(of: mixed[1], channel: $0), against: source) }
        #expect(totals.allSatisfy { abs($0) < 0.1 }, "\(totals)")
        #expect(centre.allSatisfy { abs($0 + 3.0103) < 0.01 }, "\(centre)")
        #expect(peak(of: mixed[0], channel: 1, frames: 0..<rate) == 0)
        #expect(peak(of: mixed[2], channel: 0, frames: 0..<rate) < 1e-7)
    }

    @Test("a stereo source at the centre is the decoded sound bit for bit, and panned right its left channel is silent")
    func balancesStereo() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("stereo.wav")
        try await SoundWriter(end: 1, signal: .noise(seed: 1), levels: [0.25, 0.2]).write(to: file)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())
        let source = try decoded(file)

        // When
        let centred = try sut.mix(MixPlan(length: 48000, segments: [segment(of: file, from: 0, to: 1, pan: 0)]))
        let right = try sut.mix(MixPlan(length: 48000, segments: [segment(of: file, from: 0, to: 1, pan: 1)]))

        // Then
        #expect(centred.samples == source.samples)
        #expect(peak(of: right, channel: 0, frames: 0..<rate) == 0)
        #expect(channel(1, of: right) == channel(1, of: source))
    }

    @Test("a 5.1 source at the centre is its ITU-R BS.775 downmix alone, and is balanced as stereo after it")
    func pansSurroundAfterDownmix() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("surround.wav")
        try await SoundWriter(end: 1, signal: .noise(seed: 3), levels: [0.2, 0.15, 0.1, 0.05, 0.1, 0.15]).write(to: file)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())
        let source = try decoded(file)
        let downmix = try #require(StereoDownmixer(layout: source.layout)).stereo(from: source, path: file)
        let channels = try #require(downmix.floatChannelData)
        let left = Array(UnsafeBufferPointer(start: channels[0], count: rate))
        let right = Array(UnsafeBufferPointer(start: channels[1], count: rate))

        // When
        let centred = try sut.mix(MixPlan(length: 48000, segments: [segment(of: file, from: 0, to: 1, pan: 0)]))
        let leftward = try sut.mix(MixPlan(length: 48000, segments: [segment(of: file, from: 0, to: 1, pan: -0.5)]))

        // Then
        #expect(channel(0, of: centred) == left)
        #expect(channel(1, of: centred) == right)
        #expect(channel(0, of: leftward) == left)
        #expect(channel(1, of: leftward) == right.map { $0 * 0.5 })
    }

    @Test(
        "a crossfade's middle holds the level of its ends on the curve that suits its sounds, and is 3 dB off on the other",
        arguments: crossfadeLevels
    )
    func measuresCrossfadeLevel(
        isSameSignal: Bool,
        curve: CrossfadeCurve,
        expected: Double
    ) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let first = directory.file("first.wav")
        let second = directory.file("second.wav")
        let signal: SoundSignal = isSameSignal ? .tone(frequency: 400) : .noise(seed: 1)
        try await SoundWriter(end: 3, signal: signal, levels: [0.25]).write(to: first)
        try await SoundWriter(end: 3, signal: .noise(seed: 2), levels: [0.25]).write(to: second)
        let crossfade = Crossfade(range: TimeRange(start: 1, end: 2), curve: curve)
        // Copies of one take play the same media time at every instant of the transition.
        let audio = [
            sound(first, in: 0, start: 0, end: 2, outgoing: crossfade),
            sound(isSameSignal ? first : second, in: isSameSignal ? 1 : 0, start: 1, end: 3, incoming: crossfade)
        ]
        let plan = MixPlanner().mix(of: sequence(audio, duration: 3))
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(plan)

        // Then
        let windows = windowPowers(of: mixed)
        let ends = (windows[50..<100] + windows[200..<250]).reduce(0, +) / 100
        let middle = decibels(power(of: mixed, channel: 0, frames: 71_760..<72_240), against: ends)
        let across = windows[100..<200].map { decibels($0, against: ends) }
        #expect(abs(middle - expected) < 0.5, "middle \(middle) dB, across \(across.min()!) to \(across.max()!) dB")
    }

    @Test("checking a plan refuses a segment whose file has no sound track, naming the segment and the file")
    func refusesSilentFile() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let sound = directory.file("mono.wav")
        let video = directory.file("silent.mov")
        try await SoundWriter(end: 1).write(to: sound)
        try await MovieWriter(size: Size(width: 64, height: 64), frameTimes: [0], end: 1)
            .write(to: video) { _, _ in }
        let plan = MixPlan(length: 48000, segments: [segment(of: sound, from: 0, to: 1), segment(of: video, from: 0, to: 1)])
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let error = #expect(throws: MixerError.self) { try sut.check(plan) }

        // Then
        #expect(error?.description == "mix plan segments[1]: media \(video) has no sound track")
    }

    @Test("checking a plan refuses a sound of eight channels whose file names no layout, and passes one that names 7.1")
    func refusesSoundWithoutLayout() throws {
        // Given
        let directory = try TemporaryDirectory()
        let poly = directory.file("poly.wav")
        let surround = directory.file("surround.wav")
        let channels = noises(count: 4800, seeds: [1, 2, 3, 4, 5, 6, 7, 8], level: 0.1)
        try WaveFileWriter(channels: channels).write(to: poly)
        try WaveFileWriter(channels: channels, channelMask: 0x63F).write(to: surround)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let error = #expect(throws: MixerError.self) {
            try sut.check(MixPlan(length: 4800, segments: [segment(of: poly, from: 0, to: 0.1)]))
        }

        // Then
        #expect(
            error?.description == "mix plan segments[0]: media \(poly) has 8 channels and its file names no channel "
                + "layout, so it is not downmixed to stereo"
        )
        #expect(throws: Never.self) {
            try sut.check(MixPlan(length: 4800, segments: [segment(of: surround, from: 0, to: 0.1)]))
        }
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
            try sut.check(MixPlan(length: 48000, segments: [segment(of: file, speed: 64, from: 0, to: 0.01)]))
        }

        // Then
        #expect(
            error?.description == "mix plan segments[0]: media \(file) plays at speed 64.0, outside the 1/32 to 32 its "
                + "time stretch keeps the pitch over"
        )
        #expect(throws: Never.self) {
            try sut.check(MixPlan(length: 48000, segments: [segment(of: file, speed: 0.5, from: 0, to: 1)]))
        }
    }

    @Test("a segment's filter runs before its envelope, so a fade fades the compressed sound")
    func filtersBeforeFade() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        let writer = SoundWriter(end: 1, levels: [0.5])
        try await writer.write(to: file)
        let fade = [EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: 1, value: 1)]
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let faded = try sut.mix(
            MixPlan(length: 48000, segments: [segment(of: file, from: 0, to: 1, filter: Self.compressorFilter, envelope: fade)])
        )
        let held = try sut.mix(MixPlan(length: 48000, segments: [segment(of: file, from: 0, to: 1, filter: Self.compressorFilter)]))

        // Then
        let deviation = (0..<rate).map { frame in
            abs(faded.samples[frame * 2] - Float(frame) / Float(rate) * held.samples[frame * 2])
        }.max()!
        #expect(deviation < 1e-6, "\(deviation)")
        #expect(peak(of: held, channel: 0, frames: 24_000..<rate) < 0.5 * centre * 0.9)
    }

    @Test("each segment starts its filter at rest, so the repeats of a loop sound the same")
    func startsFilterAtRestPerSegment() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        let writer = SoundWriter(end: 1, levels: [0.5])
        try await writer.write(to: file)
        let plan = MixPlan(length: 48000, segments: [
            segment(of: file, from: 0, to: 0.5, filter: Self.compressorFilter),
            segment(of: file, from: 0.5, to: 1, filter: Self.compressorFilter)
        ])
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(plan)

        // Then
        let repeated = (0..<24_000).allSatisfy { frame in
            mixed.samples[frame * 2] == mixed.samples[(24_000 + frame) * 2]
        }
        #expect(repeated)
        #expect(peak(of: mixed, channel: 0, frames: 24_000..<24_048) > 1.5 * peak(of: mixed, channel: 0, frames: 12_000..<24_000))
    }

    @Test("a filter at `mix` 0 leaves the segment's sound as it is without one")
    func passesDryAtZeroMix() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("stereo.wav")
        let writer = SoundWriter(end: 1, levels: [0.25, 0.1])
        try await writer.write(to: file)
        let dry = MixFilterEntry(operations: Self.compressorFilter[0].operations, mix: .constant(0))
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let filtered = try sut.mix(MixPlan(length: 48000, segments: [segment(of: file, from: 0, to: 1, filter: [dry])]))
        let plain = try sut.mix(MixPlan(length: 48000, segments: [segment(of: file, from: 0, to: 1)]))

        // Then
        #expect(filtered.samples == plain.samples)
    }

    @Test("a segment's limiter holds every sample of its sound under the ceiling, before the gain and the pan")
    func limitsSegment() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        let writer = SoundWriter(end: 1, levels: [0.9])
        try await writer.write(to: file)
        let limiter = MixFilterEntry(
            operations: [.limiter(MixLimiter(gain: .constant(12), ceiling: .constant(-6), lookahead: 0.005, release: .constant(0.1)))],
            mix: .constant(1)
        )
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(MixPlan(length: 48000, segments: [segment(of: file, from: 0, to: 1, filter: [limiter])]))

        // Then
        let ceiling = Float(pow(10, -6.0 / 20)) * centre
        #expect(peak(of: mixed, channel: 0, frames: 0..<rate) <= ceiling * (1 + 1e-6))
        #expect(peak(of: mixed, channel: 0, frames: 24_000..<rate) > ceiling * 0.99)
    }

    @Test("a bus with an empty chain at level 1 sums its segments and buses as if they were laid flat in the plan")
    func sumsBus() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("stereo.wav")
        try await SoundWriter(end: 2, levels: [0.25, 0.1]).write(to: file)
        let outer = segment(of: file, from: 0.25, to: 1, pan: -0.5)
        let inner = segment(of: file, mediaStart: 0.5, from: 0.5, to: 0.75, pan: 0.5)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let bused = try sut.mix(MixPlan(length: 48_000, segments: [], buses: [
            bus(from: 0.25, to: 1, segments: [outer], buses: [bus(from: 0.5, to: 0.75, segments: [inner])])
        ]))
        let flat = try sut.mix(MixPlan(length: 48_000, segments: [outer, inner]))

        // Then
        #expect(bused.samples == flat.samples)
        #expect(peak(of: bused, channel: 0, frames: 24_000..<36_000) > 0.2)
        #expect(peak(of: bused, channel: 0, frames: 0..<12_000) == 0)
    }

    @Test("a bus's fade-out scales the output of its chain: each sample is the fade's gain times the sound without the fade")
    func fadesBusAfterChain() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        try await SoundWriter(end: 1, levels: [0.5]).write(to: file)
        let fadeOut = [EnvelopePoint(time: 0, value: 1), EnvelopePoint(time: 0.5, value: 1), EnvelopePoint(time: 1, value: 0)]
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let faded = try sut.mix(MixPlan(length: 48_000, segments: [], buses: [
            bus(from: 0, to: 1, segments: [segment(of: file, from: 0, to: 1)], filter: Self.compressorFilter, envelope: fadeOut)
        ]))
        let held = try sut.mix(MixPlan(length: 48_000, segments: [], buses: [
            bus(from: 0, to: 1, segments: [segment(of: file, from: 0, to: 1)], filter: Self.compressorFilter)
        ]))

        // Then
        let deviation = (0..<rate).map { frame in
            let gain = Float(min(1, 2 - 2 * Double(frame) / Double(rate)))
            return abs(faded.samples[frame * 2] - gain * held.samples[frame * 2])
        }.max()!
        #expect(deviation < 1e-6, "\(deviation)")
        #expect(peak(of: held, channel: 0, frames: 24_000..<rate) < 0.5 * centre * 0.9)
    }

    @Test("a bus's chain starts at rest at the first sample of its span, so the buses of a loop's repeats sound the same")
    func startsBusChainAtRest() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        try await SoundWriter(end: 1, levels: [0.5]).write(to: file)
        let plan = MixPlan(length: 48_000, segments: [], buses: [
            bus(from: 0, to: 0.5, segments: [segment(of: file, from: 0, to: 0.5)], filter: Self.compressorFilter),
            bus(from: 0.5, to: 1, segments: [segment(of: file, from: 0.5, to: 1)], filter: Self.compressorFilter)
        ])
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(plan)

        // Then
        let repeated = (0..<24_000).allSatisfy { frame in
            mixed.samples[frame * 2] == mixed.samples[(24_000 + frame) * 2]
        }
        #expect(repeated)
        #expect(peak(of: mixed, channel: 0, frames: 24_000..<24_048) > 1.5 * peak(of: mixed, channel: 0, frames: 12_000..<24_000))
    }

    @Test("a bus's limiter holds the sum of its sounds under the ceiling over its whole span, reading silence around it")
    func limitsBusSum() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        try await SoundWriter(end: 1, levels: [0.9]).write(to: file)
        let limiter = MixFilterEntry(
            operations: [.limiter(MixLimiter(gain: .constant(0), ceiling: .constant(-6), lookahead: 0.005, release: .constant(0.1)))],
            mix: .constant(1)
        )
        let plan = MixPlan(length: 48_000, segments: [], buses: [
            bus(
                from: 0.25,
                to: 0.75,
                segments: [segment(of: file, from: 0.25, to: 0.75), segment(of: file, from: 0.25, to: 0.75)],
                filter: [limiter]
            )
        ])
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(plan)

        // Then
        let ceiling = Float(pow(10, -6.0 / 20))
        #expect(peak(of: mixed, channel: 0, frames: 12_000..<36_000) <= ceiling * (1 + 1e-6))
        #expect(peak(of: mixed, channel: 0, frames: 24_000..<36_000) > ceiling * 0.99)
        #expect(peak(of: mixed, channel: 0, frames: 0..<12_000) == 0)
        #expect(peak(of: mixed, channel: 0, frames: 36_000..<rate) == 0)
    }

    @Test(
        "a mix whose plan chain ends with a limiter at `mix` 1 holds every sample at or under its ceiling",
        arguments: [0.0015, 0.005, 0.05]
    )
    func limitsMix(lookahead: Double) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("stereo.wav")
        try await SoundWriter(end: 2, levels: [0.9, 0.6]).write(to: file)
        let compressor = Self.compressorFilter[0]
        let limiter = MixFilterEntry(
            operations: [.limiter(MixLimiter(gain: .constant(12), ceiling: .constant(-1), lookahead: lookahead, release: .constant(0.1)))],
            mix: .constant(1)
        )
        let plan = MixPlan(
            length: 96_000,
            segments: [segment(of: file, from: 0, to: 2)],
            buses: [bus(from: 0.5, to: 1.5, segments: [segment(of: file, mediaStart: 0.3, from: 0.5, to: 1.5, pan: 0.4)])],
            filter: [compressor, limiter]
        )
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(plan)

        // Then
        let ceiling = Float(pow(10, -1.0 / 20))
        let largest = mixed.samples.map(abs).max()!
        #expect(largest <= ceiling * (1 + 1e-6), "\(largest)")
        #expect(largest > ceiling * 0.99)
    }

    @Test("where an inner gain and the bus's level both move, the sound is their product, each joined between its own points")
    func multipliesLevelAfterSum() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("mono.wav")
        try await SoundWriter(end: 1, levels: [0.5]).write(to: file)
        let gain = [EnvelopePoint(time: 0, value: 0), EnvelopePoint(time: 1, value: 1)]
        let level = [EnvelopePoint(time: 0, value: 1), EnvelopePoint(time: 0.3, value: 0.25), EnvelopePoint(time: 1, value: 0.75)]
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(MixPlan(length: 48_000, segments: [], buses: [
            bus(from: 0, to: 1, segments: [segment(of: file, from: 0, to: 1, envelope: gain)], envelope: level)
        ]))
        let plain = try sut.mix(MixPlan(length: 48_000, segments: [segment(of: file, from: 0, to: 1)]))

        // Then
        let deviation = (0..<rate).map { frame in
            let time = Double(frame) / Double(rate)
            let joined = time < 0.3 ? 1 - 0.75 * time / 0.3 : 0.25 + 0.5 * (time - 0.3) / 0.7
            return abs(mixed.samples[frame * 2] - Float(time * joined) * plain.samples[frame * 2])
        }.max()!
        #expect(deviation < 1e-6, "\(deviation)")
    }

    @Test("a held level on a bus gives the sound a held gain on each of its segments gives, pan before the sum")
    func holdsLevelAsGain() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let file = directory.file("stereo.wav")
        try await SoundWriter(end: 1, levels: [0.25, 0.1]).write(to: file)
        let half = [EnvelopePoint(time: 0, value: 0.5), EnvelopePoint(time: 1, value: 0.5)]
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let bused = try sut.mix(MixPlan(length: 48_000, segments: [], buses: [
            bus(from: 0, to: 1, segments: [segment(of: file, from: 0, to: 1, pan: 0.3)], envelope: half)
        ]))
        let flat = try sut.mix(MixPlan(length: 48_000, segments: [segment(of: file, from: 0, to: 1, envelope: half, pan: 0.3)]))

        // Then
        #expect(bused.samples == flat.samples)
    }

    @Test("checking a plan walks its buses, naming a segment inside one by its place in the plan")
    func refusesSilentFileInBus() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let sound = directory.file("mono.wav")
        let video = directory.file("silent.mov")
        try await SoundWriter(end: 1).write(to: sound)
        try await MovieWriter(size: Size(width: 64, height: 64), frameTimes: [0], end: 1)
            .write(to: video) { _, _ in }
        let plan = MixPlan(length: 48_000, segments: [segment(of: sound, from: 0, to: 1)], buses: [
            bus(from: 0, to: 1, segments: [], buses: [
                bus(from: 0, to: 1, segments: [segment(of: sound, from: 0, to: 1), segment(of: video, from: 0, to: 1)])
            ])
        ])
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let error = #expect(throws: MixerError.self) { try sut.check(plan) }

        // Then
        #expect(error?.description == "mix plan buses[0].buses[0].segments[1]: media \(video) has no sound track")
    }

    @Test("a `convolve` whose impulse response is 1 and then zeros leaves a stereo sound as it is at `gain` 0")
    func passesIdentityImpulse() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try writeNoise(to: directory.file("input.wav"))
        let response = directory.file("identity.wav")
        try WaveFileWriter(channels: [[1] + zeros(47_999), [1] + zeros(47_999)]).write(to: response)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let convolved = try sut.mix(MixPlan(length: 48_000, segments: [
            segment(of: input, from: 0, to: 1, filter: convolution(response))
        ]))
        let plain = try sut.mix(MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 1)]))

        // Then
        #expect(convolved.samples == plain.samples)
    }

    @Test("an impulse response of 300 zeros and a 1 delays the sound by 300 samples, silence before them")
    func delaysByImpulse() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try writeNoise(to: directory.file("input.wav"))
        let response = directory.file("delayed.wav")
        try WaveFileWriter(channels: [zeros(300) + [1]]).write(to: response)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let convolved = try sut.mix(MixPlan(length: 48_000, segments: [
            segment(of: input, from: 0, to: 1, filter: convolution(response))
        ]))
        let plain = try sut.mix(MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 1)]))

        // Then
        for channel in 0..<2 {
            let output = self.channel(channel, of: convolved)
            let dry = self.channel(channel, of: plain)
            let largest = (0..<48_000).map { abs(output[$0] - ($0 < 300 ? 0 : dry[$0 - 300])) }.max()!
            #expect(largest <= 1e-6, "channel \(channel): \(largest)")
        }
    }

    @Test("an impulse response of one sample 0.25 scales the sound by 0.25 exactly")
    func scalesByImpulse() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try writeNoise(to: directory.file("input.wav"))
        let response = directory.file("quarter.wav")
        try WaveFileWriter(channels: [[0.25], [0.25]]).write(to: response)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let convolved = try sut.mix(MixPlan(length: 48_000, segments: [
            segment(of: input, from: 0, to: 1, filter: convolution(response))
        ]))
        let plain = try sut.mix(MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 1)]))

        // Then
        #expect(convolved.samples == plain.samples.map { $0 * 0.25 })
    }

    @Test(
        "`gain` raises the convolved sound by 10^(G / 20), as a number and as an envelope read at each sample",
        arguments: [
            MixValue.constant(-6),
            MixValue.envelope([EnvelopePoint(time: 0.25, value: -20), EnvelopePoint(time: 0.75, value: 6)])
        ]
    )
    func raisesByGain(gain: MixValue) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try writeNoise(to: directory.file("input.wav"))
        let response = directory.file("identity.wav")
        try WaveFileWriter(channels: [[1]]).write(to: response)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let convolved = try sut.mix(MixPlan(length: 48_000, segments: [
            segment(of: input, from: 0, to: 1, filter: convolution(response, gain: gain))
        ]))
        let plain = try sut.mix(MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 1)]))

        // Then
        var cursor = EnvelopeCursor(value: gain)
        let largest = (0..<48_000).map { frame in
            let scale = pow(10, cursor.value(at: Double(frame) / 48_000) / 20)
            return (0..<2).map { channel in
                abs(Double(convolved.samples[frame * 2 + channel]) - scale * Double(plain.samples[frame * 2 + channel]))
            }.max()!
        }.max()!
        #expect(largest <= 2 * Double(Float.ulpOfOne), "\(largest)")
    }

    @Test("an impulse response of one channel is the h of both channels at its own level: its only sample 1 changes nothing")
    func usesMonoResponseOnBoth() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try writeNoise(to: directory.file("input.wav"))
        let unit = directory.file("unit.wav")
        try WaveFileWriter(channels: [[1]]).write(to: unit)
        let taps: [Float] = [0.5, 0, 0.25]
        let shaped = directory.file("shaped.wav")
        try WaveFileWriter(channels: [taps]).write(to: shaped)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let passed = try sut.mix(MixPlan(length: 48_000, segments: [
            segment(of: input, from: 0, to: 1, filter: convolution(unit))
        ]))
        let convolved = try sut.mix(MixPlan(length: 48_000, segments: [
            segment(of: input, from: 0, to: 1, filter: convolution(shaped))
        ]))
        let plain = try sut.mix(MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 1)]))

        // Then
        #expect(passed.samples == plain.samples)
        for channel in 0..<2 {
            let reference = directSum(of: self.channel(channel, of: plain), by: taps, at: Array(0..<48_000))
            let largest = deviation(of: self.channel(channel, of: convolved), from: reference)
            #expect(largest <= 1e-6, "channel \(channel): \(largest)")
        }
    }

    @Test("an impulse response of two channels gives the left channel its left and the right its right, with no cross terms")
    func keepsStereoResponseApart() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try writeNoise(to: directory.file("input.wav"))
        let response = directory.file("stereo.wav")
        try WaveFileWriter(channels: [[1, 0], [0, 0.5]]).write(to: response)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let convolved = try sut.mix(MixPlan(length: 48_000, segments: [
            segment(of: input, from: 0, to: 1, filter: convolution(response))
        ]))
        let plain = try sut.mix(MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 1)]))

        // Then
        let left = channel(0, of: plain)
        let right = channel(1, of: plain)
        #expect(channel(0, of: convolved) == left)
        #expect(channel(1, of: convolved) == [0] + right.dropLast().map { $0 * 0.5 })
    }

    @Test("an impulse response at 44.1 kHz is resampled to 48 kHz as a segment's sound is")
    func resamplesResponse() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let click = directory.file("click.wav")
        try WaveFileWriter(channels: [[1] + zeros(47_999), [1] + zeros(47_999)]).write(to: click)
        let response = directory.file("response.wav")
        try WaveFileWriter(sampleRate: 44_100, channels: noises(count: 2000, seeds: [21, 22], level: 0.5)).write(to: response)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let convolved = try sut.mix(MixPlan(length: 48_000, segments: [
            segment(of: click, from: 0, to: 1, filter: convolution(response))
        ]))
        let played = try sut.mix(MixPlan(length: 48_000, segments: [segment(of: response, from: 0, to: 1)]))

        // Then
        let largest = zip(convolved.samples, played.samples).map { abs($0 - $1) }.max()!
        #expect(largest <= 1e-6, "\(largest)")
        #expect(peak(of: played, channel: 0, frames: 2100..<2177) > 0)
    }

    @Test("the convolved sound ends where its segment ends, its tail cut there")
    func cutsTailAtSpanEnd() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try writeNoise(to: directory.file("input.wav"))
        let response = directory.file("delayed.wav")
        try WaveFileWriter(channels: [zeros(1000) + [1]]).write(to: response)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let convolved = try sut.mix(MixPlan(length: 48_000, segments: [
            segment(of: input, from: 0, to: 0.25, filter: convolution(response))
        ]))

        // Then
        #expect(peak(of: convolved, channel: 0, frames: 11_000..<12_000) > 0.1)
        #expect(peak(of: convolved, channel: 0, frames: 12_000..<48_000) == 0)
        #expect(peak(of: convolved, channel: 1, frames: 12_000..<48_000) == 0)
    }

    @Test("a `convolve` on a sound that ends before its span rings on to the span's end, the direct sum of silence past it")
    func ringsPastSoundEnd() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = directory.file("half.wav")
        try WaveFileWriter(channels: noises(count: 24_000, seeds: [1, 2], level: 0.5)).write(to: input)
        let taps = noises(count: 3000, seeds: [29, 30], level: 0.05)
        let response = directory.file("room.wav")
        try WaveFileWriter(channels: taps).write(to: response)
        let filter = convolution(response)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let convolved = try sut.mix(MixPlan(length: 48_000, segments: [
            segment(of: input, from: 0, to: 1, filter: filter)
        ]))
        let cut = try sut.mix(MixPlan(length: 48_000, segments: [
            segment(of: input, from: 0, to: 0.5, filter: filter)
        ]))
        let plain = try sut.mix(MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 1)]))

        // Then
        #expect(Array(convolved.samples[0..<48_000]) == Array(cut.samples[0..<48_000]))
        let frames = Array(24_000..<27_100) + Array(stride(from: 27_100, to: 48_000, by: 97))
        for channel in 0..<2 {
            let reference = directSum(of: self.channel(channel, of: plain), by: taps[channel], at: frames)
            let output = self.channel(channel, of: convolved)
            let largest = deviation(of: frames.map { output[$0] }, from: reference)
            #expect(largest <= 1e-6, "channel \(channel): \(largest)")
        }
    }

    @Test("a segment without a filter whose sound ends before its span adds silence there, as one whose span ends with it")
    func addsSilencePastSoundEnd() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = directory.file("half.wav")
        try WaveFileWriter(channels: noises(count: 24_000, seeds: [1, 2], level: 0.5)).write(to: input)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let long = try sut.mix(MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 1)]))
        let short = try sut.mix(MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 0.5)]))

        // Then
        #expect(long.samples == short.samples)
        #expect(peak(of: short, channel: 0, frames: 0..<24_000) > 0.1)
    }

    @Test(
        "a `convolve` starts at rest at each segment and each bus span, so the repeats of a loop sound the same",
        arguments: [false, true]
    )
    func startsConvolutionAtRest(onBus: Bool) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try writeNoise(to: directory.file("input.wav"))
        let response = directory.file("room.wav")
        try WaveFileWriter(channels: noises(count: 6000, seeds: [23, 24], level: 0.05)).write(to: response)
        let filter = convolution(response)
        let plan = onBus
            ? MixPlan(length: 48_000, segments: [], buses: [
                bus(from: 0, to: 0.5, segments: [segment(of: input, from: 0, to: 0.5)], filter: filter),
                bus(from: 0.5, to: 1, segments: [segment(of: input, from: 0.5, to: 1)], filter: filter)
            ])
            : MixPlan(length: 48_000, segments: [
                segment(of: input, from: 0, to: 0.5, filter: filter),
                segment(of: input, from: 0.5, to: 1, filter: filter)
            ])
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(plan)

        // Then
        #expect(Array(mixed.samples[0..<48_000]) == Array(mixed.samples[48_000..<96_000]))
    }

    @Test("a `convolve` on a segment, on a bus and on the plan's filter gives the direct sum", arguments: 0..<3)
    func convolvesWherever(place: Int) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try writeNoise(to: directory.file("input.wav"))
        let taps = noises(count: 3000, seeds: [25, 26], level: 0.05)
        let response = directory.file("room.wav")
        try WaveFileWriter(channels: taps).write(to: response)
        let filter = convolution(response)
        let plan = switch place {
        case 0:
            MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 1, filter: filter)])

        case 1:
            MixPlan(length: 48_000, segments: [], buses: [
                bus(from: 0, to: 1, segments: [segment(of: input, from: 0, to: 1)], filter: filter)
            ])

        default:
            MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 1)], filter: filter)
        }
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let convolved = try sut.mix(plan)
        let plain = try sut.mix(MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 1)]))

        // Then
        let frames = Array(stride(from: 0, to: 48_000, by: 97)) + Array(2990..<3010)
        for channel in 0..<2 {
            let reference = directSum(of: self.channel(channel, of: plain), by: taps[channel], at: frames)
            let output = self.channel(channel, of: convolved)
            let largest = deviation(of: frames.map { output[$0] }, from: reference)
            #expect(largest <= 1e-6, "channel \(channel): \(largest)")
        }
    }

    @Test("a `convolve` in a bus's chain rings to the end of the bus's span and no further")
    func cutsBusTailAtSpanEnd() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try writeNoise(to: directory.file("input.wav"))
        let response = directory.file("delayed.wav")
        try WaveFileWriter(channels: [zeros(300) + [1]]).write(to: response)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let convolved = try sut.mix(MixPlan(length: 48_000, segments: [], buses: [
            bus(from: 0, to: 0.5, segments: [segment(of: input, from: 0, to: 0.5)], filter: convolution(response))
        ]))
        let plain = try sut.mix(MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 0.5)]))

        // Then
        for channel in 0..<2 {
            let output = self.channel(channel, of: convolved)
            let dry = self.channel(channel, of: plain)
            let largest = (0..<24_000).map { abs(output[$0] - ($0 < 300 ? 0 : dry[$0 - 300])) }.max()!
            #expect(largest <= 1e-6, "channel \(channel): \(largest)")
            #expect(output[24_000..<24_300].allSatisfy { $0 == 0 }, "channel \(channel)")
        }
    }

    @Test("a `convolve` in an entry at `mix` 0.5 is half the dry sound and half the wet, aligned sample for sample")
    func mixesConvolutionByHalf() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try writeNoise(to: directory.file("input.wav"))
        let taps = noises(count: 500, seeds: [27, 28], level: 0.1)
        let response = directory.file("room.wav")
        try WaveFileWriter(channels: taps).write(to: response)
        let sut = AVFoundationMixer(decoder: AVFoundationDecoder())

        // When
        let mixed = try sut.mix(MixPlan(length: 48_000, segments: [
            segment(of: input, from: 0, to: 1, filter: convolution(response, mix: .constant(0.5)))
        ]))
        let plain = try sut.mix(MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 1)]))

        // Then
        let frames = Array(0..<2000) + Array(stride(from: 2000, to: 48_000, by: 31))
        for channel in 0..<2 {
            let dry = self.channel(channel, of: plain)
            let wet = directSum(of: dry, by: taps[channel], at: frames)
            let reference = zip(frames, wet).map { 0.5 * Double(dry[$0]) + 0.5 * $1 }
            let output = self.channel(channel, of: mixed)
            let largest = deviation(of: frames.map { output[$0] }, from: reference)
            #expect(largest <= 1e-6, "channel \(channel): \(largest)")
        }
    }

    @Test(
        "checking and mixing a plan refuse an impulse response that decodes to no samples, naming the op's place",
        arguments: [
            (0, "segments[0].filter[0].ops[0]"),
            (1, "buses[0].filter[0].ops[0]"),
            (2, "filter[0].ops[0]")
        ]
    )
    func refusesEmptyResponse(
        place: Int,
        name: String
    ) async throws {
        // Given
        let directory = try TemporaryDirectory()
        let input = try writeNoise(to: directory.file("input.wav"))
        let response = directory.file("empty.wav")
        try WaveFileWriter(channels: [[1]]).write(to: response)
        let filter = convolution(response)
        let plan = switch place {
        case 0:
            MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 1, filter: filter)])

        case 1:
            MixPlan(length: 48_000, segments: [], buses: [
                bus(from: 0, to: 1, segments: [segment(of: input, from: 0, to: 1)], filter: filter)
            ])

        default:
            MixPlan(length: 48_000, segments: [segment(of: input, from: 0, to: 1)], filter: filter)
        }
        let sut = AVFoundationMixer(decoder: EmptySoundDecoder(emptyFile: response))

        // When
        let checked = #expect(throws: MixerError.self) { try sut.check(plan) }
        let mixed = #expect(throws: MixerError.self) { try sut.mix(plan) }

        // Then
        #expect(checked == .emptyImpulseResponse(place: name, file: response))
        #expect(mixed == .emptyImpulseResponse(place: name, file: response))
        #expect(checked?.description == "mix plan \(name): the impulse response \(response) has no samples")
    }

    // MARK: - Private
    private func bus(
        from start: Double,
        to end: Double,
        segments: [MixSegment],
        buses: [MixBus] = [],
        filter: [MixFilterEntry] = [],
        envelope: [EnvelopePoint]? = nil
    ) -> MixBus {
        MixBus(
            start: start,
            end: end,
            segments: segments,
            buses: buses,
            filter: filter,
            envelope: envelope ?? [EnvelopePoint(time: start, value: 1), EnvelopePoint(time: end, value: 1)]
        )
    }

    private func segment(
        of file: String,
        mediaStart: Double = 0,
        speed: Double = 1,
        from start: Double,
        to end: Double,
        filter: [MixFilterEntry] = [],
        envelope: [EnvelopePoint]? = nil,
        pan: Double = 0
    ) -> MixSegment {
        MixSegment(
            media: .unpinned(path: file),
            mediaStart: mediaStart,
            speed: speed,
            start: start,
            end: end,
            filter: filter,
            envelope: envelope ?? [EnvelopePoint(time: start, value: 1), EnvelopePoint(time: end, value: 1)],
            pan: [EnvelopePoint(time: start, value: pan), EnvelopePoint(time: end, value: pan)]
        )
    }

    // A sound of `file` heard from `start` to `end`, playing media time `in` at `start`, at volume 1 and centred.
    private func sound(
        _ file: String,
        in: Double,
        start: Double,
        end: Double,
        incoming: Crossfade? = nil,
        outgoing: Crossfade? = nil
    ) -> ResolvedSound {
        ResolvedSound(
            place: "sound",
            media: PinnedMedia(source: .file(PinnedFile(path: file, sha256: ""), frameTimes: nil)),
            nested: [],
            played: PlayedRange(map: TimeMap(origin: start, in: `in`, speed: 1), out: 100, loop: false),
            start: start,
            end: end,
            audible: TimeRange(start: start, end: end),
            volume: [Keyframe(at: start, value: 1)],
            pan: [Keyframe(at: start, value: 0)],
            fadeIn: nil,
            fadeOut: nil,
            incoming: incoming,
            outgoing: outgoing
        )
    }

    private func sequence(
        _ audio: [ResolvedSound],
        duration: Double
    ) -> ResolvedSequence {
        ResolvedSequence(
            format: ResolvedFormat(
                size: Size(width: 64, height: 64),
                fps: 30,
                duration: duration,
                background: Color(written: "#000000"),
                conform: .fit
            ),
            storyline: [],
            clips: [],
            audio: audio
        )
    }

    // One entry of one `convolve` op of the impulse response at `file`.
    private func convolution(
        _ file: String,
        gain: MixValue = .constant(0),
        mix: MixValue = .constant(1)
    ) -> [MixFilterEntry] {
        [
            MixFilterEntry(
                operations: [.convolve(MixConvolution(file: PinnedFile(path: file, sha256: ""), gain: gain))],
                mix: mix
            )
        ]
    }

    // Writes a second of stereo noise at 48 kHz to `file`, which it returns.
    private func writeNoise(to file: String) throws -> String {
        try WaveFileWriter(channels: noises(count: rate, seeds: [1, 2], level: 0.5)).write(to: file)

        return file
    }

    // Channels of `count` samples of noise in [-`level`, `level`], one seed each.
    private func noises(
        count: Int,
        seeds: [UInt64],
        level: Float
    ) -> [[Float]] {
        seeds.map { seed in
            (0..<count).map { level * Float(SoundSignal.noise(seed: seed).value(channel: 0, at: $0, sampleRate: rate)) }
        }
    }

    private func zeros(_ count: Int) -> [Float] {
        [Float](repeating: 0, count: count)
    }

    // Σ h[k] x[n - k] in double precision at each n of `frames`, x 0 before 0.
    private func directSum(
        of input: [Float],
        by taps: [Float],
        at frames: [Int]
    ) -> [Double] {
        frames.map { frame in
            (0...min(frame, taps.count - 1)).reduce(0.0) { $0 + Double(taps[$1]) * Double(input[frame - $1]) }
        }
    }

    private func deviation(
        of output: [Float],
        from reference: [Double]
    ) -> Double {
        zip(output, reference).map { abs(Double($0) - $1) }.max() ?? 0
    }

    // The first second of a file's sound as the decoder reads it.
    private func decoded(_ file: String) throws -> SoundBuffer {
        try AVFoundationDecoder().sound(of: MediaFile(path: file), from: 0, to: 1)
    }

    private func channel(
        _ channel: Int,
        of sound: SoundBuffer
    ) -> [Float] {
        stride(from: channel, to: sound.samples.count, by: sound.channels).map { sound.samples[$0] }
    }

    private func power(of samples: [Float]) -> Double {
        samples.reduce(0) { $0 + Double($1) * Double($1) } / Double(max(samples.count, 1))
    }

    private func power(
        of mixed: SoundBuffer,
        channel: Int,
        frames: Range<Int>? = nil
    ) -> Double {
        let samples = self.channel(channel, of: mixed)

        return power(of: Array(samples[frames ?? samples.indices]))
    }

    // The left channel's power in each 10 ms window from the start.
    private func windowPowers(of mixed: SoundBuffer) -> [Double] {
        let left = channel(0, of: mixed)

        return stride(from: 0, to: left.count - 479, by: 480).map { power(of: Array(left[$0..<$0 + 480])) }
    }

    private func decibels(
        _ power: Double,
        against reference: Double
    ) -> Double {
        10 * log10(power / reference)
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

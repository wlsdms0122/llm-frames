//
//  LoudnessReporterTests.swift
//  FramesTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
import FramesTestMedia
import Testing

@testable import Frames

@Suite("LoudnessReporter Tests")
struct LoudnessReporterTests {
    // MARK: - Property
    // A sound file of one second.
    private static let ding = ProbedMedia(kind: .audio, duration: 1, sound: ProbedSound(channels: 2, sampleRate: 48_000))

    // MARK: - Initializer
    // MARK: - Test
    @Test("a resolved document whose file changed since it was resolved stops as render does, before any role is called")
    func refusesChangedFile() throws {
        // Given
        let directory = try TemporaryDirectory()
        let path = directory.file("bgm.m4a")
        try Data([1, 2, 3]).write(to: URL(fileURLWithPath: path))
        let pinned = PinnedMedia(source: .file(PinnedFile(path: path, sha256: try FileHasher().sha256(ofFile: path))))
        try Data([1, 2, 4]).write(to: URL(fileURLWithPath: path))

        let log = RoleCallLog()
        let sut = LoudnessReporter(
            decoder: RecordingDecoder(log: log),
            mixer: RecordingMixer(log: log),
            mediaFacts: MediaFactTable(files: [:]),
            hasher: FileHasher()
        )

        // When
        #expect(throws: PinnedReferenceError.changedFile(path: path, place: "audio[0]")) {
            try sut.loudness(of: sequence(playing: pinned), from: nil, to: nil)
        }

        // Then
        #expect(log.calls.isEmpty)
    }

    @Test("a PDF has no sound, so its loudness stops as a still's does")
    func refusesPage() throws {
        // Given
        let log = RoleCallLog()
        let sut = LoudnessReporter(
            decoder: RecordingDecoder(log: log),
            mixer: RecordingMixer(log: log),
            mediaFacts: MediaFactTable(files: [:], pages: ["/abs/deck.pdf": [Size(width: 612, height: 792)]]),
            hasher: FileHashTable()
        )

        // When, Then
        #expect(throws: AnalysisError.noSound(file: "/abs/deck.pdf")) {
            try sut.loudness(ofMedium: "/abs/deck.pdf", from: nil, to: nil)
        }
    }

    @Test("a resolved document whose files are as they were pinned is checked by the decoder and the mixer, then mixed")
    func mixesPinnedSequence() throws {
        // Given
        let pinned = PinnedMedia(source: .file(PinnedFile(path: "/abs/bgm.m4a", sha256: "sha256-of-/abs/bgm.m4a")))
        let log = RoleCallLog()
        let sut = LoudnessReporter(
            decoder: RecordingDecoder(log: log),
            mixer: RecordingMixer(log: log),
            mediaFacts: MediaFactTable(files: [:]),
            hasher: FileHashTable()
        )
        let sequence = sequence(playing: pinned)

        // When
        let loudness = try sut.loudness(of: sequence, from: nil, to: nil)

        // Then
        #expect(log.calls == [
            .checkMedia(path: "/abs/bgm.m4a"),
            .checkPlan(MixPlanner().mix(of: sequence)),
            .mix(length: 48_000)
        ])
        #expect(loudness.integrated == nil)
    }

    @Test(
        "--from and --to pick the samples n whose time n / 48000 lies in [from, to), each edge at the first sample at or after it",
        arguments: [
            // Sample 1 lies at 20.83 µs, before 21 µs, and sample 2 after it.
            (0.000021, nil, [1: 1, 2: 0.5]),
            // Sample 2 lies at 41.67 µs, before 60 µs, and sample 3 at 62.5 µs, after it.
            (nil, 0.00006, [2: 0.5, 3: 1])
        ] as [(Double?, Double?, [Int: Float])]
    )
    func picksSamplesInRange(
        from: Double?,
        to: Double?,
        levels: [Int: Float]
    ) throws {
        // Given
        let sut = LoudnessReporter(
            decoder: RecordingDecoder(log: RoleCallLog()),
            mixer: RecordingMixer(log: RoleCallLog()) { sample in levels[sample] ?? 0 },
            mediaFacts: MediaFactTable(files: ["/abs/ding.wav": Self.ding]),
            hasher: FileHashTable()
        )

        // When
        let loudness = try sut.loudness(ofMedium: "/abs/ding.wav", from: from, to: to)

        // Then
        #expect(loudness.samplePeak == -6.02)
    }

    @Test("--from before 0 stops before anything is mixed, since the sound starts at 0")
    func refusesFromBeforeStart() throws {
        // Given
        let log = RoleCallLog()
        let sut = LoudnessReporter(
            decoder: RecordingDecoder(log: log),
            mixer: RecordingMixer(log: log),
            mediaFacts: MediaFactTable(files: ["/abs/ding.wav": Self.ding]),
            hasher: FileHashTable()
        )

        // When
        #expect(throws: AnalysisError.beforeSoundStart(option: "--from", time: -0.5)) {
            try sut.loudness(ofMedium: "/abs/ding.wav", from: -0.5, to: nil)
        }

        // Then
        #expect(!log.calls.contains(.mix(length: 48_000)))
    }

    // MARK: - Private
    // A one second sequence whose one sound plays `media` from 0.
    private func sequence(playing media: PinnedMedia) -> ResolvedSequence {
        let sound = ResolvedSound(
            place: "audio[0]",
            media: media,
            nested: [],
            played: PlayedRange(map: TimeMap(origin: 0, in: 0, speed: 1), out: 1, loop: false),
            start: 0,
            end: 1,
            audible: TimeRange(start: 0, end: 1),
            volume: [Keyframe(at: 0, value: 1)],
            pan: [Keyframe(at: 0, value: 0)],
            fadeIn: nil,
            fadeOut: nil,
            incoming: nil,
            outgoing: nil
        )

        return ResolvedSequence(
            format: ResolvedFormat(
                size: Size(width: 40, height: 30),
                fps: 2,
                duration: 1,
                background: Color(written: "#000000"),
                conform: .fit,
                colorSpace: .srgb,
                peak: nil
            ),
            storyline: [],
            clips: [],
            audio: [sound]
        )
    }
}

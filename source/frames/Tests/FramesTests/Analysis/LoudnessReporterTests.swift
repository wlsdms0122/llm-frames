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

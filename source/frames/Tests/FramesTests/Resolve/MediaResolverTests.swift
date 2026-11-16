//
//  MediaResolverTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

// `/abs/screen.mp4` holds a frame every tenth of a second, and `/abs/frames` holds twelve frames in natural order.
@Suite("MediaResolver Tests")
struct MediaResolverTests {
    // MARK: - Property
    private let sut = MediaResolver(mediaFacts: Fixture.mediaFacts, presets: Fixture.presets, library: Fixture.library)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a video keeps its probed frame timestamps, which the resolved document pins")
    func keepsVideoFrameTimes() throws {
        // When
        let media = try sut.media(of: .file("/abs/screen.mp4"), place: .root, kind: .sequence, theme: .base)

        // Then
        #expect(media.frameTimes == Fixture.screenFrameTimes)
        #expect(media.frameFiles.isEmpty)
    }

    @Test("an image sequence keeps its frame files in order, frame i at media second i / fps")
    func keepsImageSequenceFiles() throws {
        // When
        let media = try sut.media(
            of: .imageSequence(directory: "/abs/frames", fps: 30),
            place: .root,
            kind: .sequence,
            theme: .base
        )

        // Then
        #expect(media.frameFiles == Fixture.imageSequenceFiles)
        #expect(media.frameFiles[9] == "/abs/frames/frame-10.png")
        #expect(media.frameTimes == (0..<12).map { Double($0) / 30 })
        #expect(media.duration == 12 / 30.0)
    }

    // MARK: - Private
}

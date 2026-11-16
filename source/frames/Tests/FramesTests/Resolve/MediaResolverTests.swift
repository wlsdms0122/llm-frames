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
        let file = try #require(media.file)
        #expect(file.frameTimes == Fixture.screenFrameTimes)
        #expect(file.frameFiles.isEmpty)
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
        let file = try #require(media.file)
        #expect(file.path == "/abs/frames")
        #expect(file.frameFiles == Fixture.imageSequenceFiles)
        #expect(file.frameFiles[9] == "/abs/frames/frame-10.png")
        #expect(file.frameTimes == (0..<12).map { Double($0) / 30 })
        #expect(media.duration == 12 / 30.0)
    }

    @Test(
        "media the probe cannot read stops at the place it is named, with the probe's reason",
        arguments: [
            (MediaSource.file("/abs/broken.mp4"), "/abs/broken.mp4"),
            (MediaSource.imageSequence(directory: "/abs/torn", fps: 30), "/abs/torn")
        ]
    )
    func refusesUnreadableMedia(
        source: MediaSource,
        reference: String
    ) throws {
        // Given
        let mediaFacts = MediaFactTable(
            files: [:],
            failures: [reference: ProbeFailure("media \(reference) cannot be read")]
        )
        let sut = MediaResolver(mediaFacts: mediaFacts, presets: Fixture.presets, library: Fixture.library)
        let place = Place(components: [.key("storyline"), .index(0, id: nil), .key("media")])

        // When
        let error = #expect(throws: ResolveError.self) {
            try sut.media(of: source, place: place, kind: .genericClip(.storyline), theme: .base)
        }

        // Then
        #expect(error == .unreadableMedia(
            place: place,
            kind: .genericClip(.storyline),
            reference: reference,
            reason: "media \(reference) cannot be read"
        ))
    }

    // MARK: - Private
}

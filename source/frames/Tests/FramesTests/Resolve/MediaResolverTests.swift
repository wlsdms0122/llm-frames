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
        let media = try sut.media(
            of: .file("/abs/screen.mp4"),
            place: .root,
            kind: .sequence,
            theme: .base,
            colorSpace: nil
        )

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
            theme: .base,
            colorSpace: nil
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
            try sut.media(of: source, place: place, kind: .genericClip(.storyline), theme: .base, colorSpace: nil)
        }

        // Then
        #expect(error == .unreadableMedia(
            place: place,
            kind: .genericClip(.storyline),
            reference: reference,
            reason: "media \(reference) cannot be read"
        ))
    }

    @Test("a picture no fixed formula converts stops at the place that names it and writes no colour space")
    func refusesUnconvertibleColor() throws {
        // Given
        let sut = MediaResolver(mediaFacts: unconvertibleFacts, presets: Fixture.presets, library: Fixture.library)
        let place = Place(components: [.key("storyline"), .index(0, id: nil), .key("media")])

        // When
        let error = #expect(throws: ResolveError.self) {
            try sut.media(
                of: .file("/abs/print.jpg"),
                place: place,
                kind: .genericClip(.storyline),
                theme: .base,
                colorSpace: nil
            )
        }

        // Then
        #expect(error == .unconvertibleMediaColor(
            place: place,
            kind: .genericClip(.storyline),
            reference: "/abs/print.jpg"
        ))
        #expect(error?.description.contains("colorSpace") == true)
        #expect(error?.description.contains("transcode") == true)
    }

    @Test("a transition's cover or matte no fixed formula converts stops where its preset writes no colour space")
    func refusesUnconvertibleTransitionColor() throws {
        // Given
        let sut = MediaResolver(mediaFacts: unconvertibleFacts, presets: Fixture.presets, library: Fixture.library)
        let place = Place(components: [.key("storyline"), .index(1, id: nil), .key("transition")])

        // When
        let error = #expect(throws: ResolveError.self) {
            try sut.transitionMedia(at: "/abs/print.jpg", place: place, kind: .clip(.media(.video)), colorSpace: nil)
        }

        // Then
        #expect(error == .unconvertibleMediaColor(place: place, kind: .clip(.media(.video)), reference: "/abs/print.jpg"))
    }

    @Test("a picture no fixed formula converts is read where its place writes the colour space it is in")
    func readsUnconvertibleColorInWrittenSpace() throws {
        // Given
        let sut = MediaResolver(mediaFacts: unconvertibleFacts, presets: Fixture.presets, library: Fixture.library)

        // When
        let media = try sut.media(
            of: .file("/abs/print.jpg"),
            place: .root,
            kind: .genericClip(.storyline),
            theme: .base,
            colorSpace: .srgb
        )
        let matte = try sut.transitionMedia(
            at: "/abs/print.jpg",
            place: .root,
            kind: .clip(.media(.video)),
            colorSpace: .srgb
        )

        // Then
        #expect(media.file?.path == "/abs/print.jpg")
        #expect(matte.file.path == "/abs/print.jpg")
    }

    // MARK: - Private
    // `/abs/print.jpg` is an image whose ICC profile is LUT-based.
    private var unconvertibleFacts: MediaFactTable {
        MediaFactTable(files: [
            "/abs/print.jpg": ProbedMedia(
                kind: .image,
                size: Size(width: 40, height: 30),
                colorSpace: ProbedColorSpace(
                    reading: .platform,
                    primaries: nil,
                    transfer: nil,
                    matrix: nil,
                    bitDepth: 8,
                    isHighDynamicRange: false
                )
            )
        ])
    }
}

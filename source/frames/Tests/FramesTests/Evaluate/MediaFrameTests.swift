//
//  MediaFrameTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("MediaFrame Tests")
struct MediaFrameTests {
    // MARK: - Property
    private let files = ["a", "b", "c"].map { PinnedFile(path: "/abs/frames/\($0).png", sha256: String(repeating: $0, count: 64)) }

    // MARK: - Initializer
    // MARK: - Test
    @Test("an image sequence's frame is its file at that index, picked by the frame times")
    func picksImageSequenceFile() {
        // Given
        let media = PinnedMedia(source: .imageSequence(files, frameTimes: [0, 0.04, 0.08]))

        // When
        let sut = MediaFrame(media: media, mediaTime: 0.05, play: .file)

        // Then
        #expect(sut.picture == .frame(1))
        #expect(sut.file == files[1])
    }

    @Test("a video's frame is read from the video file at the index of the last frame at or before the time")
    func picksVideoFrame() {
        // Given
        let media = PinnedMedia(source: .file(files[0], frameTimes: [0, 0.5, 1, 1.5]))

        // When
        let sut = MediaFrame(media: media, mediaTime: 1.2, play: .file)

        // Then
        #expect(sut.picture == .frame(2))
        #expect(sut.file == files[0])
    }

    @Test("a still has the one frame 0")
    func stillHasFrameZero() {
        // Given
        let media = PinnedMedia(source: .file(files[2], frameTimes: nil))

        // When
        let sut = MediaFrame(media: media, mediaTime: 3, play: .file)

        // Then
        #expect(sut.picture == .frame(0))
        #expect(sut.file == files[2])
    }

    @Test("a page of a PDF is read as that page, by no frame, and with no target peak")
    func readsPageAsPage() {
        // Given
        let media = PinnedMedia(source: .page(files[0], page: 2))

        // When
        let sut = MediaFrame(media: media, index: 3, play: .file, reading: .working(colorSpace: .srgb, targetPeak: 1000))

        // Then
        #expect(sut.picture == .page)
        #expect(sut.reading == .working(colorSpace: .srgb, targetPeak: nil))
        #expect(sut.file == files[0])
    }
}

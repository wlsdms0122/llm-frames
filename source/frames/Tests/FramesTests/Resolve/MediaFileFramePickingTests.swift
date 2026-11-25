//
//  MediaFileFramePickingTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames
import Testing

@Suite("MediaFile frame picking Tests")
struct MediaFileFramePickingTests {
    // MARK: - Property
    private static let file = MediaFile.video("/media/a.mov", frameTimes: [0, 0.2, 0.4])
    private static let media = PinnedMedia(
        source: .file(PinnedFile(path: "/media/a.mov", sha256: ""), frameTimes: [0, 0.2, 0.4])
    )

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a media time picks the frame whose interval holds it, and one a hair before a timestamp picks that frame",
        arguments: [(0.0, 0), (0.1, 0), (0.7 - 0.5, 1), (0.2 - 2e-6, 0), (0.4 - 1e-6, 1), (0.39, 1), (0.4, 2), (9.0, 2), (-1.0, 0)]
    )
    func picksFrame(
        time: Double,
        index: Int
    ) {
        #expect(Self.file.frameIndex(at: time) == index)
        #expect(Self.media.frameIndex(at: time) == index)
        #expect(Self.file.frameTime(at: time) == Self.file.frameTimes[index])
    }

    @Test("the frame after a media time a hair before a timestamp is the one after that timestamp")
    func picksNextFrame() {
        #expect(Self.file.frameTime(after: 0.7 - 0.5) == 0.4)
        #expect(Self.file.frameTime(after: 0.1) == 0.2)
        #expect(Self.file.frameTime(after: 0.4) == nil)
    }

    // MARK: - Private
}

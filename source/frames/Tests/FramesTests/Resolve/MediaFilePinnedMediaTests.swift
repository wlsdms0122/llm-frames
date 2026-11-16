//
//  MediaFilePinnedMediaTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

@testable import Frames
import Testing

@Suite("MediaFile+PinnedMedia Tests")
struct MediaFilePinnedMediaTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("pinned media gives the decoder its file and frame times, and an image sequence its directory and frame files")
    func convertsPinnedMedia() {
        // Given
        let video = PinnedMedia(source: .file(PinnedFile(path: "/media/a.mov", sha256: "")), frameTimes: [0, 0.5])
        let sequence = PinnedMedia(
            source: .imageSequence([
                PinnedFile(path: "/media/shots/0001.png", sha256: ""),
                PinnedFile(path: "/media/shots/0002.png", sha256: "")
            ]),
            frameTimes: [0, 0.04]
        )

        // When
        let videoFile = MediaFile(media: video)
        let sequenceFile = MediaFile(media: sequence)

        // Then
        #expect(videoFile == MediaFile(path: "/media/a.mov", frameTimes: [0, 0.5]))
        #expect(
            sequenceFile == MediaFile(
                path: "/media/shots",
                frameTimes: [0, 0.04],
                frameFiles: ["/media/shots/0001.png", "/media/shots/0002.png"]
            )
        )
    }
}

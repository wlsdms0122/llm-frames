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
        let video = PinnedMedia(source: .file(PinnedFile(path: "/media/a.mov", sha256: ""), frameTimes: [0, 0.5]))
        let sequence = PinnedMedia(
            source: .imageSequence([
                PinnedFile(path: "/media/shots/0001.png", sha256: ""),
                PinnedFile(path: "/media/shots/0002.png", sha256: "")
            ], frameTimes: [0, 0.04])
        )

        // When
        let videoFile = MediaFile(picture: video)
        let sequenceFile = MediaFile(picture: sequence)

        // Then
        #expect(videoFile == MediaFile(
            path: "/media/a.mov",
            kind: .video(frameTimes: [0, 0.5], fps: nil, size: nil, colorReading: nil)
        ))
        #expect(sequenceFile == MediaFile(
            path: "/media/shots",
            kind: .imageSequence(
                frameFiles: ["/media/shots/0001.png", "/media/shots/0002.png"],
                frameTimes: [0, 0.04],
                fps: nil,
                size: nil,
                colorReading: nil
            )
        ))
    }

    @Test("pinned media of a file without frames is an image where a picture is read and a sound file where a sound is")
    func tellsStillFromSound() {
        // Given
        let media = PinnedMedia(source: .file(PinnedFile(path: "/media/a.png", sha256: ""), frameTimes: nil))

        // When
        let picture = MediaFile(picture: media)
        let sound = MediaFile(sound: media)

        // Then
        #expect(picture == MediaFile(path: "/media/a.png", kind: .still(size: nil, colorReading: nil)))
        #expect(sound == MediaFile(path: "/media/a.png", kind: .sound))
    }

    @Test("pinned media of a video read for its sound is the video with its frames")
    func readsVideoSoundAsVideo() {
        // Given
        let media = PinnedMedia(source: .file(PinnedFile(path: "/media/a.mov", sha256: ""), frameTimes: [0, 0.5]))

        // When
        let sut = MediaFile(sound: media)

        // Then
        #expect(sut == MediaFile(
            path: "/media/a.mov",
            kind: .video(frameTimes: [0, 0.5], fps: nil, size: nil, colorReading: nil)
        ))
    }
}

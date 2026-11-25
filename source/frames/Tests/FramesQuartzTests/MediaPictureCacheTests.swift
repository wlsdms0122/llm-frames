//
//  MediaPictureCacheTests.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/26/26.
//

import Foundation
import Frames
@testable import FramesQuartz
import Testing

// A renderer keeps the media pictures of the frame it drew last for the next frame, and lets go of every other, so
// the pictures it holds are bounded by what one frame shows, however many files a sequence shows in turn.
@Suite("MediaPictureCache Tests")
struct MediaPictureCacheTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a frame's picture the frame drawn last used is read once, and one it did not use is read again")
    func keepsPicturesOfFrameDrawnLast() throws {
        // Given
        let decoder = ReadingDecoder()
        let sut = QuartzRenderer(decoder: decoder)
        let first = item(showing: "/cache/first.mov")
        let second = item(showing: "/cache/second.mov")

        // When
        _ = try sut.frame(of: list(of: [first, second]))
        _ = try sut.frame(of: list(of: [first]))
        _ = try sut.frame(of: list(of: [first, second]))

        // Then
        #expect(decoder.readings(of: "/cache/first.mov").count == 1)
        #expect(decoder.readings(of: "/cache/second.mov").count == 2)
    }

    @Test("files shown one after another and then again are read again, since none is kept past the frame after it")
    func keepsNoFileShownBefore() throws {
        // Given
        let decoder = ReadingDecoder()
        let sut = QuartzRenderer(decoder: decoder)
        let paths = (0..<8).map { "/cache/\($0).mov" }

        // When
        for path in paths {
            _ = try sut.frame(of: list(of: [item(showing: path)]))
            _ = try sut.frame(of: list(of: [item(showing: path)]))
        }
        for path in paths {
            _ = try sut.frame(of: list(of: [item(showing: path)]))
        }

        // Then
        #expect(paths.map { decoder.readings(of: $0).count } == Array(repeating: 2, count: paths.count))
    }

    // MARK: - Private
    // A picture item of frame 0 of the video at `path`, filling a 2 by 2 list.
    private func item(showing path: String) -> DisplayItem {
        let frame = MediaFrame(
            media: PinnedMedia(source: .file(PinnedFile(path: path, sha256: ""), frameTimes: [0])),
            index: 0
        )
        let picture = PictureItem(
            source: .media(frame),
            rectangle: nil,
            destination: Rectangle(x: 0, y: 0, width: 2, height: 2)
        )

        return DisplayItem(content: .picture(picture))
    }

    private func list(of items: [DisplayItem]) -> DisplayList {
        DisplayList(size: Size(width: 2, height: 2), background: Color(written: "#000000"), seed: 0, items: items)
    }
}

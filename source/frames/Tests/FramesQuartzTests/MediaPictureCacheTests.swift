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
// the pictures it holds are bounded by what one frame shows, however many files a sequence shows in turn, and the run's
// budget counts them within the floor the renderer's check of each list gives (FRAMES-30 The budget).
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

    @Test("checking a list raises the budget's pictures floor to twice the pictures of pixels it reads, each once")
    func reservesPicturesOfList() throws {
        // Given
        let budget = MemoryBudget(limit: .unlimited)
        let sut = QuartzRenderer(decoder: ReadingDecoder(), budget: budget)
        let first = item(showing: "/cache/first.mov")
        let page = MediaFrame(
            media: PinnedMedia(source: .page(PinnedFile(path: "/cache/page.pdf", sha256: ""), page: 1)),
            index: 0,
            play: .file
        )
        let pageItem = DisplayItem(
            content: .picture(
                PictureItem(source: .media(page), rectangle: nil, destination: Rectangle(x: 0, y: 0, width: 2, height: 2))
            )
        )

        // When
        try sut.check(list(of: [first, item(showing: "/cache/second.mov"), first, pageItem]))

        // Then
        let pictures = try #require(budget.usage.holders.first { $0.holder == .pictures })
        #expect(pictures.floor == 2 * 2 * 32)
    }

    @Test("the pictures kept over frames whose lists were checked are counted within the floor their checks give")
    func countsPicturesWithinFloor() throws {
        // Given
        let budget = MemoryBudget(limit: .unlimited)
        let sut = QuartzRenderer(decoder: ReadingDecoder(), budget: budget)
        let lists = [
            list(of: [item(showing: "/cache/a.mov"), item(showing: "/cache/b.mov")]),
            list(of: [item(showing: "/cache/c.mov"), item(showing: "/cache/d.mov")]),
            list(of: [item(showing: "/cache/a.mov")])
        ]
        for list in lists {
            try sut.check(list)
        }

        // When
        for list in lists {
            _ = try sut.frame(of: list)
        }

        // Then
        let pictures = try #require(budget.usage.holders.first { $0.holder == .pictures })
        #expect(pictures.floor == 2 * 2 * 32)
        #expect(pictures.peak == pictures.floor)
    }

    @Test("a frame two plays of one file show is read once, and a list's check counts its picture once")
    func readsFrameOfTwoPlaysOnce() throws {
        // Given
        let budget = MemoryBudget(limit: .unlimited)
        let decoder = ReadingDecoder()
        let sut = QuartzRenderer(decoder: decoder, budget: budget)
        let tiles = list(of: [
            item(showing: "/cache/tile.mov", play: .place("clips[0]")),
            item(showing: "/cache/tile.mov", play: .place("clips[1]"))
        ])

        // When
        try sut.check(tiles)
        _ = try sut.frame(of: tiles)

        // Then
        #expect(decoder.readings(of: "/cache/tile.mov").count == 1)
        let pictures = try #require(budget.usage.holders.first { $0.holder == .pictures })
        #expect(pictures.floor == 2 * 32)
    }

    // MARK: - Private
    // A picture item of frame 0 of the video at `path` in `play`, filling a 2 by 2 list.
    private func item(
        showing path: String,
        play: MediaPlay = .file
    ) -> DisplayItem {
        let frame = MediaFrame(
            media: PinnedMedia(source: .file(PinnedFile(path: path, sha256: ""), frameTimes: [0])),
            index: 0,
            play: play
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

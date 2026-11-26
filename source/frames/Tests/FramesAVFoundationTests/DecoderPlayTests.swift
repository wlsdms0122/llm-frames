//
//  DecoderPlayTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/26/26.
//

import Foundation
import Frames
@testable import FramesAVFoundation
import FramesTestMedia
import Testing

// A reader for each play of a video: two clips of one file each read it forward from a reader of their own, and the
// bound and the budget count both readers (FRAMES-21 Rules). Serialized, so that the tests running at once read far
// fewer files with AVFoundation than the 64 at once at which its reads stop finishing (FRAMES-21 Notes).
@Suite("Decoder Play Tests", .serialized, .ownThread)
struct DecoderPlayTests {
    // MARK: - Property
    private static let size = Size(width: 320, height: 240)
    private static let times = (0..<40).map { Double($0) / 30 }

    // MARK: - Initializer
    // MARK: - Test
    @Test("two plays of one file read in turn each read forward from a reader of their own and open it once")
    func readsEachPlayForward() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let media = try await Self.movie(in: directory)
        let sut = AVFoundationDecoder()
        let first = MediaPlay.place("clips[0]")
        let second = MediaPlay.place("clips[1]")

        // When
        var codes: [Int] = []
        for index in 0..<10 {
            codes.append(code(in: try sut.picture(of: media, atFrame: index, play: first, reading: .tagged).bitmap))
            codes.append(code(in: try sut.picture(of: media, atFrame: 20 + index, play: second, reading: .tagged).bitmap))
        }

        // Then
        #expect(codes == (0..<10).flatMap { [$0, 20 + $0] })
        let reading = try #require(sut.readings().media.first)
        #expect(reading.framesRead == 20)
        #expect(reading.reopened == 0)
        #expect(reading.framesDecoded <= 2 * reading.framesRead)
    }

    @Test("a play whose frames go backward opens its reader again once, and another play's reader stays where it was")
    func reopensPlayGoingBackward() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let media = try await Self.movie(in: directory)
        let sut = AVFoundationDecoder()
        let first = MediaPlay.place("clips[0]")
        let second = MediaPlay.place("clips[1]")

        // When
        for (index, play) in [(5, first), (20, second), (6, first), (21, second), (2, first), (22, second)] {
            _ = try sut.picture(of: media, atFrame: index, play: play, reading: .tagged)
        }

        // Then
        let reading = try #require(sut.readings().media.first)
        #expect(reading.reopened == 1)
    }

    @Test("the budget charges a reader for each play of a file")
    func chargesReaderOfEachPlay() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let media = try await Self.movie(in: directory)
        let single = MemoryBudget(limit: .unlimited)
        let double = MemoryBudget(limit: .unlimited)
        let one = AVFoundationDecoder(budget: single)
        let sut = AVFoundationDecoder(budget: double)

        // When
        _ = try one.picture(of: media, atFrame: 0, play: .place("clips[0]"), reading: .tagged)
        _ = try sut.picture(of: media, atFrame: 0, play: .place("clips[0]"), reading: .tagged)
        _ = try sut.picture(of: media, atFrame: 20, play: .place("clips[1]"), reading: .tagged)

        // Then
        let reader = try #require(single.usage.holders.first { $0.holder == .readers })
        let readers = try #require(double.usage.holders.first { $0.holder == .readers })
        #expect(reader.peak > 0)
        #expect(readers.peak == 2 * reader.peak)
    }

    @Test("the bound counts the readers of two plays of one file as two")
    func boundsReadersOfPlays() throws {
        // Given
        let sut = ReaderBound<VideoPlay>(count: 2, budget: MemoryBudget(limit: .unlimited))
        let first = VideoPlay(path: "/plays/tile.mov", play: .place("clips[0]"))
        let second = VideoPlay(path: "/plays/tile.mov", play: .place("clips[1]"))
        let other = VideoPlay(path: "/plays/other.mov", play: .place("clips[2]"))

        // When
        let firstClosing = try sut.admit(first, cost: 1, turnRoom: 0) { _ in false }.closing
        let secondClosing = try sut.admit(second, cost: 1, turnRoom: 0) { _ in false }.closing
        let otherClosing = try sut.admit(other, cost: 1, turnRoom: 0) { _ in false }.closing

        // Then
        #expect(firstClosing.isEmpty && secondClosing.isEmpty)
        #expect(otherClosing == [first])
        #expect(sut.isOpen(second) && sut.isOpen(other) && !sut.isOpen(first))
    }

    // MARK: - Private
    // A video of 40 frames at 30 fps, each showing its index as a code.
    private static func movie(in directory: TemporaryDirectory) async throws -> MediaFile {
        let movie = directory.file("code.mp4")
        try await MovieWriter(size: size, frameTimes: times, end: 40.0 / 30).write(to: movie) { canvas, index in
            canvas.fill(red: 40, green: 90, blue: 200)
            canvas.drawCode(index)
        }

        return MediaFile.video(movie, frameTimes: times, size: size)
    }

    // The number a picture of the code movie is drawn with, its bits left to right along the top.
    private func code(in picture: Bitmap) -> Int {
        (0..<6).reduce(0) { value, bit in
            red(in: picture, x: bit * 16 + 8, y: 8) > 0.5 ? value | 1 << bit : value
        }
    }

    // The red component at a pixel of a half float picture.
    private func red(
        in picture: Bitmap,
        x: Int,
        y: Int
    ) -> Double {
        let start = y * picture.bytesPerRow + x * 8

        return picture.pixels[start..<start + 2].withUnsafeBytes { Double($0.load(as: Float16.self)) }
    }
}

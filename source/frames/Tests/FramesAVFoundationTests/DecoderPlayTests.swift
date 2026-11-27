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

// A reader for each play of a video: two clips of one file each read it forward from a reader of their own, the
// bound and the budget count both readers, a play told each frame it asks next reads forward whatever the steps
// between its frames, and a play neither a rendered frame nor the frames told for the next show ends (FRAMES-21 Rules).
// Serialized, so that the tests running at once read far fewer files with AVFoundation than the 64 at once at which
// its reads stop finishing (FRAMES-21 Notes).
@Suite("Decoder Play Tests", .serialized, .ownThread)
struct DecoderPlayTests {
    // MARK: - Property
    private static let size = Size(width: 320, height: 240)
    private static let times = (0..<40).map { Double($0) / 30 }
    // The bytes the budget counts a frame read ahead of the code movie at, its displayed size at 8 bytes a pixel.
    private static let frameBytes = Int(size.width * size.height) * 8

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

    @Test("a play a rendered frame does not show is over, and the budget counts only what the shown play holds")
    func endsPlaysNotShown() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let media = try await Self.movie(in: directory)
        let single = MemoryBudget(limit: .unlimited)
        let budget = MemoryBudget(limit: try #require(MemorySize("1GB")))
        _ = try AVFoundationDecoder(budget: single).picture(of: media, atFrame: 0, play: .file, reading: .tagged)
        let reader = try #require(single.usage.holders.first { $0.holder == .readers }).peak
        let sut = AVFoundationDecoder(budget: budget)
        let first = MediaPlay.place("clips[0]")
        let second = MediaPlay.place("clips[1]")
        for index in 0..<4 {
            _ = try sut.picture(of: media, atFrame: index, play: first, reading: .tagged)
            _ = try sut.picture(of: media, atFrame: 20 + index, play: second, reading: .tagged)
        }
        sut.readAhead(of: media, atFrames: [24], play: second, reading: .tagged)
        let before = budget.counted

        // When
        sut.frameRendered(showing: [Self.frame(of: media, at: 23, play: second)])
        let shown = budget.counted
        sut.frameRendered(showing: [])

        // Then
        #expect(before == 2 * reader + Self.frameBytes)
        #expect(shown == reader + Self.frameBytes)
        #expect(budget.counted == reader)
    }

    @Test("fifty cuts of one file, each its own play and each frame told the next, never hold more than the plays of two frames")
    func boundsFiftyCuts() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let media = try await Self.movie(in: directory)
        let single = MemoryBudget(limit: .unlimited)
        let budget = MemoryBudget(limit: try #require(MemorySize("1GB")))
        _ = try AVFoundationDecoder(budget: single).picture(of: media, atFrame: 0, play: .file, reading: .tagged)
        let reader = try #require(single.usage.holders.first { $0.holder == .readers }).peak
        let sut = AVFoundationDecoder(budget: budget)
        let starts = (0..<50).map { $0 * 7 % 34 }
        let shown = starts.enumerated().flatMap { cut, start in
            (start..<(start + 4)).map { (play: MediaPlay.place("storyline[\(cut)]"), index: $0) }
        }

        // When
        var codes: [Int] = []
        for (place, frame) in shown.enumerated() {
            let picture = try sut.picture(of: media, atFrame: frame.index, play: frame.play, reading: .tagged)
            codes.append(code(in: picture.bitmap))
            if let next = shown.dropFirst(place + 1).first {
                sut.readAhead(of: media, atFrames: [next.index], play: next.play, reading: .tagged)
            }
            sut.frameRendered(showing: [Self.frame(of: media, at: frame.index, play: frame.play)])
        }

        // Then
        #expect(codes == shown.map(\.index))
        let peaks = Dictionary(uniqueKeysWithValues: budget.usage.holders.map { ($0.holder, $0.peak) })
        #expect(peaks[.readers] == 2 * reader)
        #expect(try #require(peaks[.readAhead]) <= 2 * Self.frameBytes)
        #expect(peaks[.turns] == 0)
        #expect(budget.counted <= reader + Self.frameBytes)
    }

    @Test("a clip hidden and shown again reads its frames as a new play, whose first reader is not one opened again")
    func startsPlayShownAgain() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let media = try await Self.movie(in: directory)
        let sut = AVFoundationDecoder()
        let play = MediaPlay.place("clips[0]")
        for index in 20..<24 {
            _ = try sut.picture(of: media, atFrame: index, play: play, reading: .tagged)
            sut.frameRendered(showing: [Self.frame(of: media, at: index, play: play)])
        }
        sut.frameRendered(showing: [])

        // When
        var codes: [Int] = []
        for index in 2..<6 {
            codes.append(code(in: try sut.picture(of: media, atFrame: index, play: play, reading: .tagged).bitmap))
            sut.frameRendered(showing: [Self.frame(of: media, at: index, play: play)])
        }

        // Then
        #expect(codes == [2, 3, 4, 5])
        let reading = try #require(sut.readings().media.first)
        #expect(reading.reopened == 0)
    }

    @Test("a play read forward through a video whose frame intervals vary, told each frame it asks next, never opens its reader again")
    func readsUnevenIntervalsForward() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let intervals = [0.008, 0.030, 0.012, 0.025, 0.016, 0.009, 0.028]
        let times = (0..<60).map { index in (0..<index).reduce(0) { $0 + intervals[$1 % intervals.count] } }
        let movie = directory.file("uneven.mp4")
        let writer = MovieWriter(size: Self.size, frameTimes: times, end: times[times.count - 1] + 0.02)
        try await writer.write(to: movie) { canvas, index in
            canvas.fill(red: 40, green: 90, blue: 200)
            canvas.drawCode(index)
        }
        let media = MediaFile.video(movie, frameTimes: times, size: Self.size)
        let indices = (0..<30).map { media.frameIndex(at: Double($0) / 30) }
        let sut = AVFoundationDecoder()
        let play = MediaPlay.place("clips[0]")

        // When
        var codes: [Int] = []
        for (place, index) in indices.enumerated() {
            codes.append(code(in: try sut.picture(of: media, atFrame: index, play: play, reading: .tagged).bitmap))
            if indices.indices.contains(place + 1) {
                sut.readAhead(of: media, atFrames: [indices[place + 1]], play: play, reading: .tagged)
            }
            sut.frameRendered(showing: [Self.frame(of: media, at: index, play: play, frameTimes: times)])
        }

        // Then
        let steps = Set(zip(indices, indices.dropFirst()).map { $1 - $0 })
        #expect(steps.count > 1)
        #expect(codes == indices)
        let reading = try #require(sut.readings().media.first)
        #expect(reading.framesRead == indices.count)
        #expect(reading.reopened == 0)
        #expect(reading.framesDecoded <= indices[indices.count - 1] + 1)
    }

    @Test("a play the frame rendered does not show but the frame after it is told to is kept, its reader not opened again")
    func keepsPlayToldForNextFrame() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let media = try await Self.movie(in: directory)
        let sut = AVFoundationDecoder()
        let first = MediaPlay.place("storyline[0]")
        let second = MediaPlay.place("storyline[1]")
        _ = try sut.picture(of: media, atFrame: 10, play: second, reading: .tagged)
        sut.frameRendered(showing: [Self.frame(of: media, at: 10, play: second)])
        _ = try sut.picture(of: media, atFrame: 2, play: first, reading: .tagged)
        sut.readAhead(of: media, atFrames: [11], play: second, reading: .tagged)

        // When
        sut.frameRendered(showing: [Self.frame(of: media, at: 2, play: first)])
        let picture = try sut.picture(of: media, atFrame: 11, play: second, reading: .tagged)

        // Then
        #expect(code(in: picture.bitmap) == 11)
        let reading = try #require(sut.readings().media.first)
        #expect(reading.framesRead == 3)
        #expect(reading.reopened == 0)
    }

    // MARK: - Private
    // Frame `index` of a movie of `frameTimes` shown in `play`, as a display list names it.
    private static func frame(
        of media: MediaFile,
        at index: Int,
        play: MediaPlay,
        frameTimes: [Double] = times
    ) -> MediaFrame {
        let file = PinnedFile(path: media.path, sha256: String(repeating: "0", count: 64))

        return MediaFrame(media: PinnedMedia(source: .file(file, frameTimes: frameTimes)), index: index, play: play)
    }

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

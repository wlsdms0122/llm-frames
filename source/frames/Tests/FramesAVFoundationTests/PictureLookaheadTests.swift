//
//  PictureLookaheadTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/26/26.
//

import Foundation
import Frames
import FramesTestMedia
import os
import Testing
@testable import FramesAVFoundation

// Reading ahead the frames a caller tells, on threads of their own, and no more frames at once than the machine has
// processors, so reads at once stay well under the 64 at which AVFoundation's reads stop finishing (FRAMES-21 Notes).
@Suite("PictureLookahead Tests", .ownThread)
struct PictureLookaheadTests {
    // MARK: - Property
    private let processors = ProcessInfo.processInfo.activeProcessorCount

    // MARK: - Initializer
    // MARK: - Test
    @Test("seventy files each told a frame together are read ahead no more at once than the machine has processors")
    func boundsReadsAhead() throws {
        // Given
        let sut = PictureLookahead(budget: MemoryBudget(limit: .unlimited))
        let files = (0..<70).map { VideoPlay(path: "/lookahead/\($0).mov", play: .file) }
        let gate = DispatchSemaphore(value: 0)
        let reads = OSAllocatedUnfairLock(initialState: (running: 0, most: 0))
        let readAhead: @Sendable (Int) throws -> Pixels = { index in
            reads.withLock { $0 = (running: $0.running + 1, most: max($0.most, $0.running + 1)) }
            gate.wait()
            gate.signal()
            reads.withLock { $0.running -= 1 }

            return .bitmap(Self.picture(index))
        }

        // When
        for file in files {
            sut.readAhead(atFrames: [2], of: file, reading: .tagged, bytes: 8, read: readAhead)
        }
        let start = ContinuousClock.now
        while reads.withLock({ $0.running }) < processors, ContinuousClock.now - start < .seconds(10) {
            Thread.sleep(forTimeInterval: 0.01)
        }
        Thread.sleep(forTimeInterval: 0.2)
        let most = reads.withLock { $0.most }
        gate.signal()
        let pictures = try files.map { file in
            try sut.picture(atFrame: 2, of: file, reading: .tagged) { .bitmap(Self.picture($0)) }.bitmap
        }

        // Then
        #expect(most == processors)
        #expect(pictures.allSatisfy { $0 == Self.picture(2) })
    }

    @Test("two plays of one file each read ahead the frames told for them, in the order told, and no others")
    func readsAheadFramesTold() throws {
        // Given
        let sut = PictureLookahead(budget: MemoryBudget(limit: .unlimited))
        let first = VideoPlay(path: "/lookahead/tile.mov", play: .place("clips[0]"))
        let second = VideoPlay(path: "/lookahead/tile.mov", play: .place("clips[1]"))
        let reads = OSAllocatedUnfairLock<[(play: VideoPlay, index: Int, isAhead: Bool)]>(initialState: [])
        let read = { (play: VideoPlay, isAhead: Bool) -> @Sendable (Int) throws -> Pixels in
            { index in
                reads.withLock { $0.append((play, index, isAhead)) }

                return .bitmap(Self.picture(index))
            }
        }

        // When
        var pictures: [Bitmap] = []
        for (play, indices) in [(first, [0, 2, 3, 6]), (second, [20, 21, 25, 26])] {
            pictures.append(try sut.picture(atFrame: indices[0], of: play, reading: .tagged, read: read(play, false)).bitmap)
            sut.readAhead(atFrames: Array(indices.dropFirst()), of: play, reading: .tagged, bytes: 8, read: read(play, true))
        }
        for (play, indices) in [(first, [2, 3, 6]), (second, [21, 25, 26])] {
            for index in indices {
                pictures.append(try sut.picture(atFrame: index, of: play, reading: .tagged, read: read(play, false)).bitmap)
            }
        }

        // Then
        #expect(pictures == [0, 20, 2, 3, 6, 21, 25, 26].map(Self.picture))
        let ahead = reads.withLock { $0 }.filter(\.isAhead)
        #expect(ahead.filter { $0.play == first }.map(\.index) == [2, 3, 6])
        #expect(ahead.filter { $0.play == second }.map(\.index) == [21, 25, 26])
        #expect(reads.withLock { $0 }.filter { !$0.isAhead }.map(\.index) == [0, 20])
    }

    @Test("a frame asked that was not told is read where it is asked once the play's frames being read ahead are read")
    func readsFrameNotToldAfterReadsAhead() throws {
        // Given
        let sut = PictureLookahead(budget: MemoryBudget(limit: .unlimited))
        let play = VideoPlay(path: "/lookahead/tile.mov", play: .place("clips[0]"))
        let gate = DispatchSemaphore(value: 0)
        let reads = OSAllocatedUnfairLock<[Int]>(initialState: [])
        sut.readAhead(atFrames: [4], of: play, reading: .tagged, bytes: 8) { index in
            gate.wait()
            reads.withLock { $0.append(index) }

            return .bitmap(Self.picture(index))
        }

        // When
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { gate.signal() }
        let picture = try sut.picture(atFrame: 3, of: play, reading: .tagged) { index in
            reads.withLock { $0.append(index) }

            return .bitmap(Self.picture(index))
        }

        // Then
        #expect(picture.bitmap == Self.picture(3))
        #expect(reads.withLock { $0 } == [4, 3])
    }

    @Test(
        "seventy videos read forward frame by frame together, as a render reads seventy clips shown at once, give every frame",
        .timeLimit(.minutes(2))
    )
    func readsSeventyVideosTogether() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let size = Size(width: 320, height: 240)
        let times = (0..<10).map { Double($0) / 30 }
        let movie = directory.file("code.mp4")
        try await MovieWriter(size: size, frameTimes: times, end: 10.0 / 30).write(to: movie) { canvas, index in
            canvas.fill(red: 40, green: 90, blue: 200)
            canvas.drawCode(index)
        }
        let files = try (0..<70).map { index in
            let file = directory.file("code-\(index).mp4")
            try FileManager.default.linkItem(atPath: movie, toPath: file)

            return MediaFile.video(file, frameTimes: times, size: size)
        }
        let sut = AVFoundationDecoder()

        // When
        let codes = try times.indices.map { index in
            try files.map { file in
                let picture = try sut.picture(of: file, atFrame: index, play: .file, reading: .tagged).bitmap
                sut.readAhead(of: file, atFrames: [index + 1], play: .file, reading: .tagged)

                return code(in: picture)
            }
        }

        // Then
        #expect(codes == times.indices.map { Array(repeating: $0, count: files.count) })
    }

    @Test("a play the decoder keeps no longer is dropped once a frame is rendered, the frames read ahead for it given back")
    func endsPlayNotKept() throws {
        // Given
        let budget = MemoryBudget(limit: try #require(MemorySize("1MB")))
        let sut = PictureLookahead(budget: budget)
        let first = VideoPlay(path: "/lookahead/tile.mov", play: .place("clips[0]"))
        let second = VideoPlay(path: "/lookahead/tile.mov", play: .place("clips[1]"))
        let read: @Sendable (Int) throws -> Pixels = { index in .bitmap(Self.picture(index)) }
        sut.readAhead(atFrames: [2, 3], of: first, reading: .tagged, bytes: 8, read: read)
        sut.readAhead(atFrames: [22], of: second, reading: .tagged, bytes: 8, read: read)
        let heldBefore = budget.counted

        // When
        sut.frameRendered(keeping: [second])
        let heldKept = budget.counted
        sut.frameRendered(keeping: [])

        // Then
        #expect(heldBefore == 24)
        #expect(heldKept == 8)
        #expect(budget.counted == 0)
    }

    @Test("a frame read ahead that the frame it was told for did not ask is let go of once that frame is rendered")
    func letsGoOfFrameNotAsked() throws {
        // Given
        let budget = MemoryBudget(limit: try #require(MemorySize("1MB")))
        let sut = PictureLookahead(budget: budget)
        let play = VideoPlay(path: "/lookahead/tile.mov", play: .place("clips[0]"))
        let read: @Sendable (Int) throws -> Pixels = { index in .bitmap(Self.picture(index)) }
        sut.readAhead(atFrames: [1, 2], of: play, reading: .tagged, bytes: 8, read: read)
        sut.frameRendered(keeping: [play])
        let heldTold = budget.counted

        // When
        let picture = try sut.picture(atFrame: 1, of: play, reading: .tagged) { _ in .bitmap(Self.picture(0)) }
        let heldAsked = budget.counted
        sut.frameRendered(keeping: [play])

        // Then
        #expect(picture.bitmap == Self.picture(1))
        #expect(heldTold == 16)
        #expect(heldAsked == 8)
        #expect(budget.counted == 0)
    }

    @Test("a telling for a play and reading lets go of the frames read ahead for them that it does not name")
    func letsGoOfFramesNotToldAgain() throws {
        // Given
        let budget = MemoryBudget(limit: try #require(MemorySize("1MB")))
        let sut = PictureLookahead(budget: budget)
        let play = VideoPlay(path: "/lookahead/tile.mov", play: .file)
        let read: @Sendable (Int) throws -> Pixels = { index in .bitmap(Self.picture(index)) }
        sut.readAhead(atFrames: [1, 2], of: play, reading: .tagged, bytes: 8, read: read)
        sut.readAhead(atFrames: [1], of: play, reading: .analysis(colorSpace: nil), bytes: 4, read: read)

        // When
        sut.readAhead(atFrames: [2, 3], of: play, reading: .tagged, bytes: 8, read: read)

        // Then
        #expect(budget.counted == 20)
    }

    @Test("a told frame past the budget's room, and those told after it with it, are read where they are asked")
    func readsFramesPastRoomWhereAsked() throws {
        // Given
        let budget = MemoryBudget(limit: try #require(MemorySize("1MB")))
        budget.require(budget.limit.bytes - 16, for: .pictures)
        budget.hold(budget.limit.bytes - 16, for: .pictures)
        let sut = PictureLookahead(budget: budget)
        let play = VideoPlay(path: "/lookahead/tile.mov", play: .file)
        let aheads = OSAllocatedUnfairLock<[Int]>(initialState: [])
        let read: @Sendable (Int) throws -> Pixels = { index in
            aheads.withLock { $0.append(index) }

            return .bitmap(Self.picture(index))
        }

        // When
        sut.readAhead(atFrames: [1, 2, 3], of: play, reading: .tagged, bytes: 8, read: read)
        let pictures = try [1, 2, 3].map { index in
            try sut.picture(atFrame: index, of: play, reading: .tagged) { .bitmap(Self.picture($0)) }.bitmap
        }

        // Then
        #expect(pictures == [1, 2, 3].map(Self.picture))
        #expect(aheads.withLock { $0 } == [1, 2])
    }

    // MARK: - Private
    // A picture of one pixel whose red is `index`.
    private static func picture(_ index: Int) -> Bitmap {
        Bitmap(width: 1, height: 1, depth: .eight, bytesPerRow: 4, pixels: Data([UInt8(index), 0, 0, 255]))
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

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

// Reading ahead on threads of its own, and no more frames at once than the machine has processors, so reads at once
// stay well under the 64 at which AVFoundation's reads stop finishing (FRAMES-21 Notes).
@Suite("PictureLookahead Tests", .ownThread)
struct PictureLookaheadTests {
    // MARK: - Property
    private let processors = ProcessInfo.processInfo.activeProcessorCount

    // MARK: - Initializer
    // MARK: - Test
    @Test("seventy files read forward together are read ahead no more at once than the machine has processors")
    func boundsReadsAhead() throws {
        // Given
        let sut = PictureLookahead(budget: MemoryBudget(limit: .unlimited))
        let files = (0..<70).map { VideoPlay(path: "/lookahead/\($0).mov", play: .file) }
        let gate = DispatchSemaphore(value: 0)
        let reads = OSAllocatedUnfairLock(initialState: (running: 0, most: 0))
        let read: @Sendable (Int, Bool) throws -> Pixels = { index, isAhead in
            if isAhead {
                reads.withLock { $0 = (running: $0.running + 1, most: max($0.most, $0.running + 1)) }
                gate.wait()
                gate.signal()
                reads.withLock { $0.running -= 1 }
            }

            return .bitmap(Self.picture(index))
        }

        // When
        for file in files {
            for index in 0..<2 {
                _ = try sut.picture(atFrame: index, of: file, count: 3, bytes: 8, reading: .tagged, read: read)
            }
        }
        let start = ContinuousClock.now
        while reads.withLock({ $0.running }) < processors, ContinuousClock.now - start < .seconds(10) {
            Thread.sleep(forTimeInterval: 0.01)
        }
        Thread.sleep(forTimeInterval: 0.2)
        let most = reads.withLock { $0.most }
        gate.signal()
        let pictures = try files.map { file in
            try sut.picture(atFrame: 2, of: file, count: 3, bytes: 8, reading: .tagged, read: read).bitmap
        }

        // Then
        #expect(most == processors)
        #expect(pictures.allSatisfy { $0 == Self.picture(2) })
    }

    @Test("two plays of one file read in turn are each read ahead by their own step")
    func readsAheadByEachPlaysStep() throws {
        // Given
        let sut = PictureLookahead(budget: MemoryBudget(limit: .unlimited))
        let first = VideoPlay(path: "/lookahead/tile.mov", play: .place("clips[0]"))
        let second = VideoPlay(path: "/lookahead/tile.mov", play: .place("clips[1]"))
        let aheads = OSAllocatedUnfairLock<[Int]>(initialState: [])
        let read: @Sendable (Int, Bool) throws -> Pixels = { index, isAhead in
            if isAhead { aheads.withLock { $0.append(index) } }

            return .bitmap(Self.picture(index))
        }

        // When
        var pictures: [Bitmap] = []
        for step in 0..<3 {
            pictures.append(try sut.picture(atFrame: step, of: first, count: 40, bytes: 8, reading: .tagged, read: read).bitmap)
            pictures.append(
                try sut.picture(atFrame: 20 + step, of: second, count: 40, bytes: 8, reading: .tagged, read: read).bitmap
            )
        }
        _ = try sut.picture(atFrame: 3, of: first, count: 40, bytes: 8, reading: .tagged, read: read)
        _ = try sut.picture(atFrame: 23, of: second, count: 40, bytes: 8, reading: .tagged, read: read)

        // Then
        #expect(pictures == [0, 20, 1, 21, 2, 22].map(Self.picture))
        // The frames read ahead of the frames asked last, 4 and 24, may not have started.
        let started = Set(aheads.withLock { $0 })
        #expect(Set([2, 3, 22, 23]).isSubset(of: started))
        #expect(started.isSubset(of: [2, 3, 4, 22, 23, 24]))
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
                code(in: try sut.picture(of: file, atFrame: index, play: .file, reading: .tagged).bitmap)
            }
        }

        // Then
        #expect(codes == times.indices.map { Array(repeating: $0, count: files.count) })
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

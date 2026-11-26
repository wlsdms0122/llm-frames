//
//  VideoReaderTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/26/26.
//

import CoreVideo
import Foundation
import Frames
@testable import FramesAVFoundation
import FramesTestMedia
import Testing

// A video's reader reading frames in a turn and holding them (FRAMES-21 Rules). Serialized, so that the tests running
// at once read far fewer files with AVFoundation than the 64 at once at which its reads stop finishing (FRAMES-21
// Notes).
@Suite("VideoReader Tests", .serialized, .ownThread)
struct VideoReaderTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a reader opened for a turn holds the frames it read past the one asked, and a reader opened again is counted")
    func holdsTurnFrames() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let movie = try await Self.movie(in: directory)
        let sut = try #require(try VideoReader(path: movie))

        // When
        let first = try #require(try sut.buffer(atFrame: 2, path: movie, turn: 4) { true })
        let held = (0..<12).filter { sut.holds(frame: $0) }
        let fromHeld = try #require(try sut.buffer(atFrame: 4, path: movie, turn: 1) { true })
        let heldAfter = (0..<12).filter { sut.holds(frame: $0) }
        sut.close()
        let again = try #require(try sut.buffer(atFrame: 9, path: movie, turn: 1) { true })

        // Then
        #expect(!first.reopened)
        #expect(held == [3, 4, 5])
        #expect(fromHeld.decoded == 0 && !fromHeld.reopened)
        #expect(heldAfter == [5])
        #expect(again.reopened)
        #expect(!sut.holdsFrames)
    }

    @Test("a turn reads the frames after the one asked by the step from the frame asked before it")
    func holdsTurnFramesByStep() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let movie = try await Self.movie(in: directory)
        let sut = try #require(try VideoReader(path: movie))
        _ = try sut.buffer(atFrame: 0, path: movie, turn: 1) { true }
        _ = try sut.buffer(atFrame: 2, path: movie, turn: 1) { true }
        sut.close()

        // When
        let turn = try #require(try sut.buffer(atFrame: 4, path: movie, turn: 4) { true })
        let held = (0..<12).filter { sut.holds(frame: $0) }

        // Then
        #expect(turn.reopened)
        #expect(held == [6, 8, 10])
    }

    @Test("a frame that needs a reader opened opens none where the reader is not admitted, and a held frame needs none")
    func opensOnlyAdmittedReader() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let movie = try await Self.movie(in: directory)
        let sut = try #require(try VideoReader(path: movie))
        _ = try sut.buffer(atFrame: 0, path: movie, turn: 3) { true }
        sut.close()

        // When
        let fromHeld = try sut.buffer(atFrame: 1, path: movie, turn: 1) { false }
        let refused = try sut.buffer(atFrame: 6, path: movie, turn: 1) { false }
        let heldAfterRefusal = (0..<12).filter { sut.holds(frame: $0) }
        let admitted = try sut.buffer(atFrame: 6, path: movie, turn: 1) { true }

        // Then
        #expect(fromHeld?.decoded == 0)
        #expect(refused == nil)
        #expect(heldAfterRefusal == [2])
        #expect(admitted?.reopened == true)
    }

    @Test("a turn holds as many of its frames as the budget grants its turns, gives them back as they are let go of, and a frame it does not hold is read from the reader")
    func holdsTurnFramesWithinBudget() async throws {
        // Given
        let directory = try TemporaryDirectory()
        let movie = try await Self.movie(in: directory)
        let probe = try #require(try VideoReader(path: movie))
        let bytes = CVPixelBufferGetDataSize(try #require(try probe.buffer(atFrame: 0, path: movie, turn: 1) { true }).buffer)
        let budget = MemoryBudget(limit: .unlimited)
        let limited = MemoryBudget(limit: try #require(MemorySize("1MB")))
        limited.require(MemorySize.megabyte - 2 * bytes, for: .frames)
        let sut = try #require(try VideoReader(path: movie, budget: limited))
        let free = try #require(try VideoReader(path: movie, budget: budget))

        // When
        _ = try sut.buffer(atFrame: 2, path: movie, turn: 6) { true }
        let held = (0..<12).filter { sut.holds(frame: $0) }
        let past = try #require(try sut.buffer(atFrame: 5, path: movie, turn: 1) { true })
        _ = try free.buffer(atFrame: 2, path: movie, turn: 6) { true }
        _ = try free.buffer(atFrame: 9, path: movie, turn: 1) { true }

        // Then
        #expect(held == [3, 4])
        #expect(!past.reopened)
        let turns = try #require(limited.usage.holders.first { $0.holder == .turns })
        #expect(turns.refused == 1 && turns.peak == 2 * bytes)
        let freeTurns = try #require(budget.usage.holders.first { $0.holder == .turns })
        #expect(freeTurns.peak == 5 * bytes && freeTurns.refused == 0)
    }

    // MARK: - Private
    // A video of 12 frames at 30 fps, each showing its index as a code.
    private static func movie(in directory: TemporaryDirectory) async throws -> String {
        let times = (0..<12).map { Double($0) / 30 }
        let movie = directory.file("code.mp4")
        try await MovieWriter(size: Size(width: 64, height: 48), frameTimes: times, end: 12.0 / 30)
            .write(to: movie) { canvas, index in
                canvas.fill(red: 40, green: 90, blue: 200)
                canvas.drawCode(index)
            }

        return movie
    }
}

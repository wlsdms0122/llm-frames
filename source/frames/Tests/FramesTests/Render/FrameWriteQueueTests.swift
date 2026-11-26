//
//  FrameWriteQueueTests.swift
//  FramesTests
//
//  Created by JSilver on 11/24/26.
//

import Foundation
import Testing

@testable import Frames

@Suite("FrameWriteQueue Tests")
struct FrameWriteQueueTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("every writer takes every frame in the order appended, and is finished after its last frame")
    func writesFramesInOrder() throws {
        // Given
        let log = RoleCallLog()
        let paths = ["/abs/a.mov", "/abs/b.mp4"]
        let sut = FrameWriteQueue(
            writers: paths.map { RecordingVideoWriter(path: $0, log: log) },
            budget: MemoryBudget(limit: .unlimited),
            frameBytes: 1
        )

        // When
        for frame in 0..<8 {
            try sut.append(.bitmap(Bitmap(frame: frame)))
        }
        try sut.finish()

        // Then
        for path in paths {
            let taken = log.calls.filter { call in
                if case .append(path, _) = call { return true }

                return call == .finish(path: path)
            }
            #expect(taken == (0..<8).map { .append(path: path, frame: $0) } + [.finish(path: path)])
        }
    }

    @Test("a writer that fails stops the queue, which throws its error and finishes no writer")
    func throwsWriterFailure() throws {
        // Given
        let log = RoleCallLog()
        let sut = FrameWriteQueue(
            writers: [RecordingVideoWriter(path: "/abs/a.mov", log: log), FailingVideoWriter()],
            budget: MemoryBudget(limit: .unlimited),
            frameBytes: 1
        )

        // When
        let error = #expect(throws: FailingVideoWriter.Failure.self) {
            for frame in 0..<8 {
                try sut.append(.bitmap(Bitmap(frame: frame)))
            }
            try sut.finish()
        }

        // Then
        #expect(error == .refused)
        #expect(!log.calls.contains(.finish(path: "/abs/a.mov")))
    }

    @Test("a second frame waits behind the one being written where the budget grants its bytes, and else the queue waits for the first", arguments: [
        ("3MB", 0, 3),
        ("2MB", 1, 2)
    ])
    func holdsSecondFrameWithinBudget(
        limit: String,
        refused: Int,
        peak: Int
    ) throws {
        // Given
        let megabyte = MemorySize.megabyte
        let budget = MemoryBudget(limit: try #require(MemorySize(limit)))
        budget.require(2 * megabyte, for: .frames)
        budget.hold(megabyte, for: .frames)
        let gate = DispatchSemaphore(value: 0)
        let sut = FrameWriteQueue(writers: [GatedVideoWriter(gate: gate)], budget: budget, frameBytes: megabyte)

        // When
        try sut.append(.bitmap(Bitmap(frame: 0)))
        DispatchQueue(label: "gate").asyncAfter(deadline: .now() + 0.2) {
            gate.signal()
            gate.signal()
        }
        try sut.append(.bitmap(Bitmap(frame: 1)))
        try sut.finish()

        // Then
        let frames = try #require(budget.usage.holders.first { $0.holder == .frames })
        #expect(frames.refused == refused)
        #expect(frames.peak == peak * megabyte)
    }
}

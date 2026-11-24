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
        let sut = FrameWriteQueue(writers: paths.map { RecordingVideoWriter(path: $0, log: log) })

        // When
        for frame in 0..<8 {
            try sut.append(Bitmap(frame: frame))
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
        let sut = FrameWriteQueue(writers: [
            RecordingVideoWriter(path: "/abs/a.mov", log: log),
            FailingVideoWriter()
        ])

        // When
        let error = #expect(throws: FailingVideoWriter.Failure.self) {
            for frame in 0..<8 {
                try sut.append(Bitmap(frame: frame))
            }
            try sut.finish()
        }

        // Then
        #expect(error == .refused)
        #expect(!log.calls.contains(.finish(path: "/abs/a.mov")))
    }
}

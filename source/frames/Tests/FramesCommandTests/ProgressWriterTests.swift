//
//  ProgressWriterTests.swift
//  FramesCommandTests
//
//  Created by JSilver on 11/25/26.
//

import Frames
import Testing

@testable import FramesCommand

@Suite("ProgressWriter Tests")
struct ProgressWriterTests {
    // MARK: - Property
    private let recorder = OutputRecorder()

    // MARK: - Initializer
    // MARK: - Test
    @Test("text writes a line for the first frame a second or more after the last line or the run's start, and for the last frame always, on standard error")
    func writesTextAtMostOnceASecond() {
        // Given
        let sut = ProgressWriter(format: .text, output: recorder.output)

        // When
        write([(1, 0.25), (2, 0.5), (3, 1), (4, 1.5), (5, 1.75), (6, 2.25), (7, 2.5)], frames: 7, to: sut)

        // Then
        #expect(recorder.standardError == "frame 3/7\nframe 6/7\nframe 7/7\n")
        #expect(recorder.standardOutput.isEmpty)
    }

    @Test("json writes each line as the progress object, and the last frame even within a second of the line before")
    func writesJSONLines() {
        // Given
        let sut = ProgressWriter(format: .json, output: recorder.output)

        // When
        write([(1, 1.5), (2, 1.75)], frames: 2, to: sut)

        // Then
        #expect(recorder.standardError == """
            {"progress": "0.1.0", "frame": 1, "frames": 2, "seconds": 1.5}
            {"progress": "0.1.0", "frame": 2, "frames": 2, "seconds": 1.75}

            """)
    }

    @Test("none writes nothing, the last frame included")
    func writesNothing() {
        // Given
        let sut = ProgressWriter(format: .none, output: recorder.output)

        // When
        write([(1, 1), (2, 3)], frames: 2, to: sut)

        // Then
        #expect(recorder.standardError.isEmpty)
    }

    @Test("a run of one frame writes its one line however soon it is drawn")
    func writesOneFrame() {
        // Given
        let sut = ProgressWriter(format: .text, output: recorder.output)

        // When
        write([(1, 0.01)], frames: 1, to: sut)

        // Then
        #expect(recorder.standardError == "frame 1/1\n")
    }

    // MARK: - Private
    private func write(
        _ drawn: [(frame: Int, seconds: Double)],
        frames: Int,
        to writer: ProgressWriter
    ) {
        for (frame, seconds) in drawn {
            writer.write(RunProgress(frame: frame, frames: frames, seconds: seconds))
        }
    }
}

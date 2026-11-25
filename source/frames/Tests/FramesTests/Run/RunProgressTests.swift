//
//  RunProgressTests.swift
//  FramesTests
//
//  Created by JSilver on 11/25/26.
//

import Testing

@testable import Frames

@Suite("RunProgress Tests")
struct RunProgressTests {
    // MARK: - Property
    private let sut = RunProgress(frame: 12, frames: 48, seconds: 1.2500004)

    // MARK: - Initializer
    // MARK: - Test
    @Test("a line of --progress json is the progress object FRAMES-23 gives on one line, its seconds to the microsecond")
    func writesJSONLine() {
        // When
        let line = JSONWriter().writeLine(sut.machineOutput)

        // Then
        #expect(line == #"{"progress": "0.1.0", "frame": 12, "frames": 48, "seconds": 1.25}"# + "\n")
    }

    @Test("a line of --progress text names the frames drawn of the run's frames")
    func writesText() {
        // Then
        #expect(sut.text == "frame 12/48")
    }

    // MARK: - Private
}

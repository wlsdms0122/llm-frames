//
//  FrameRangeTests.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Testing

@testable import Frames

@Suite("FrameRange Tests")
struct FrameRangeTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "a range runs from + k x step while the time is before to, measured to the microsecond",
        arguments: [
            (FrameRange(), 3.5, [0, 1, 2, 3]),
            (FrameRange(), 3, [0, 1, 2]),
            (FrameRange(from: 0.5, to: 2, step: 0.5), 3, [0.5, 1, 1.5]),
            (FrameRange(to: 0.3, step: 0.1), 1, [0, 0.1, 0.2]),
            (FrameRange(from: 2.9), 3, [2.9])
        ] as [(FrameRange, Double, [Double])]
    )
    func runsFromStepToEnd(
        range: FrameRange,
        end: Double,
        expected: [Double]
    ) throws {
        // Given
        let sut = range

        // When
        let times = try sut.times(end: end, kind: "video")

        // Then
        #expect(times.map(\.timeTicks) == expected.map(\.timeTicks))
    }

    @Test(
        "a step under a microsecond, a time outside the media and an empty range stop",
        arguments: [
            (FrameRange(step: 0), ExportError.nonPositiveStep(0)),
            (FrameRange(step: 0.0000001), ExportError.nonPositiveStep(0.0000001)),
            (FrameRange(step: 0.0000006), ExportError.nonPositiveStep(0.0000006)),
            (FrameRange(from: -1), ExportError.timeOutside(option: "--from", time: -1, end: 3, kind: "video")),
            (FrameRange(from: 3), ExportError.timeOutside(option: "--from", time: 3, end: 3, kind: "video")),
            (FrameRange(to: 3.5), ExportError.endPastEnd(time: 3.5, end: 3, kind: "video")),
            (FrameRange(from: 2, to: 1), ExportError.emptyRange(from: 2, to: 1)),
            (FrameRange(from: 1, to: 1.0000001), ExportError.emptyRange(from: 1, to: 1.0000001))
        ]
    )
    func refusesBadRange(
        range: FrameRange,
        expected: ExportError
    ) {
        // Given
        let sut = range

        // When, Then
        #expect(throws: expected) { try sut.times(end: 3, kind: "video") }
    }

    @Test("each time is given rounded to the microsecond, so it is the time its label reads")
    func roundsToMicrosecond() throws {
        // Given
        let sut = FrameRange(step: 0.3)

        // When
        let times = try sut.times(end: 2, kind: "sequence")

        // Then
        #expect(0 + 6 * 0.3 != 1.8)
        #expect(times == [0, 0.3, 0.6, 0.9, 1.2, 1.5, 1.8])
    }

    @Test("a stop names the option and the time")
    func namesOption() {
        // Given
        let sut = FrameRange(from: 4)

        // When
        let error = #expect(throws: ExportError.self) { try sut.times(end: 2.5, kind: "sequence") }

        // Then
        #expect(error?.description == "--from 4: the sequence has no frame then, since it runs over [0, 2.5)")
    }

    // MARK: - Private
}

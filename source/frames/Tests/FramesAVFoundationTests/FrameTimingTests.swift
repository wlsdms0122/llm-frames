//
//  FrameTimingTests.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/17/26.
//

import CoreMedia
import Foundation
@testable import FramesAVFoundation
import Testing

@Suite("FrameTiming Tests")
struct FrameTimingTests {
    // MARK: - Property
    // A frame rate, the timescale it gets, and how long a frame is on it.
    private static let rates: [(Double, CMTimeScale, CMTimeValue)] = [
        (30, 30_000, 1000),
        (29.999998, 30_000, 1000),
        (24, 24_000, 1000),
        (23.976, 24_000, 1001),
        (29.97, 30_000, 1001),
        (59.94, 60_000, 1001),
        (24_000.0 / 1001, 24_000, 1001),
        (12.5, 1_000_000, 80_000)
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("a frame rate gets a timescale on which every frame lasts the same whole number of units", arguments: rates)
    func picksExactTimescale(
        fps: Double,
        timescale: CMTimeScale,
        frameDuration: CMTimeValue
    ) {
        // Given
        let sut = FrameTiming(fps: fps)

        // When
        let times = [0, 1, 2, 100_000].map { sut.time(ofFrame: $0) }

        // Then
        #expect(sut.timescale == timescale)
        #expect(times.map(\.value) == [0, 1, 2, 100_000].map { $0 * frameDuration })
    }

    @Test("a rate within a hundred-thousandth of a whole or an NTSC rate is exactly that rate", arguments: [
        (29.999998, 30),
        (29.97002997, 30_000.0 / 1001),
        (23.976, 24_000.0 / 1001),
        (12.5, 12.5)
    ])
    func readsExactRate(fps: Double, rate: Double) {
        // Given
        let sut = FrameTiming(fps: fps)

        // When
        let read = sut.rate

        // Then
        #expect(read == rate)
    }

    @Test("an NTSC rate written in decimals does not drift from k × 1001 / 30000 over hours")
    func keepsNTSCTimesFromDrifting() {
        // Given
        let sut = FrameTiming(fps: 29.97)
        let frame = 30 * 60 * 60 * 3

        // When
        let time = sut.time(ofFrame: frame)

        // Then
        #expect(time == CMTime(value: CMTimeValue(frame) * 1001, timescale: 30_000))
    }
}

//
//  GrainSeederTests.swift
//  FramesTests
//
//  Created by JSilver on 11/16/26.
//

import Testing

@testable import Frames

@Suite("GrainSeeder Tests")
struct GrainSeederTests {
    // MARK: - Property
    private let sut = GrainSeeder()

    // MARK: - Initializer
    // MARK: - Test
    @Test(
        "frame k of a sequence, evaluated at k / fps, has seed k",
        arguments: [
            (0, 30.0), (1, 30.0), (3, 30.0), (7, 30.0), (29, 30.0), (1001, 30.0),
            (5, 24.0), (13, 25.0), (59, 60.0), (12345, 60.0), (7, 50.0)
        ]
    )
    func seedsFrameNumber(frame: Int, fps: Double) {
        // Given
        let time = Double(frame) / fps

        // When
        let seed = sut.seed(at: time, fps: fps)

        // Then
        #expect(seed == frame)
    }

    @Test(
        "a time between frames has the seed of the frame whose interval holds it",
        arguments: [(0.05, 30.0, 1), (0.0999, 30.0, 2), (1.01, 25.0, 25), (0.99, 24.0, 23)]
    )
    func seedsHoldingFrame(time: Double, fps: Double, frame: Int) {
        // Given, When
        let seed = sut.seed(at: time, fps: fps)

        // Then
        #expect(seed == frame)
    }
}

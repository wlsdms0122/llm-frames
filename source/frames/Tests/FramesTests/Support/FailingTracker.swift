//
//  FailingTracker.swift
//  FramesTests
//
//  Created by JSilver on 11/19/26.
//

@testable import Frames

// A fake tracker that fails on every target with `failure`.
struct FailingTracker: TrackerProvider {
    // MARK: - Property
    let failure: any Error

    // MARK: - Initializer
    init(_ failure: any Error) {
        self.failure = failure
    }

    // MARK: - Public
    func track(
        _ target: Quad,
        in file: MediaFile,
        atMediaTime time: Double,
        over range: ClosedRange<Double>,
        colorSpace: ColorSpace?
    ) throws -> [TrackedFrame] {
        throw failure
    }

    // MARK: - Private
}

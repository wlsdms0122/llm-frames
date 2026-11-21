//
//  MotionBlurReads.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The record of whether the samples of one frame read a value owned by a clip with `motionBlur`, which decides whether
// the frame is given as samples (FRAMES-29). Each frame has its own record. It is not `Sendable`: it holds its flag
// without a lock, so it is written from one task.
final class MotionBlurReads {
    // MARK: - Property
    private(set) var readsMotionBlur = false

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func recordRead() {
        readsMotionBlur = true
    }

    // MARK: - Private
}

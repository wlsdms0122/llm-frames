//
//  MotionBlurReads.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The record of whether the samples of one frame read a value owned by a clip with `motionBlur`, which decides whether
// the frame is given as samples (FRAMES-29). Each frame has its own record, and its samples are evaluated one after
// another, so the record is written by one sample at a time and takes no lock.
final class MotionBlurReads: @unchecked Sendable {
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

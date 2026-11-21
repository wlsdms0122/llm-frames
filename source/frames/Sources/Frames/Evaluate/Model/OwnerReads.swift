//
//  OwnerReads.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

import Foundation

// What the samples of one frame have read: whether any value they read is owned by a clip with `motionBlur`, which
// decides whether the frame is given as samples (FRAMES-29).
final class OwnerReads: @unchecked Sendable {
    // MARK: - Property
    private let lock = NSLock()
    private var isMotionBlurRead = false

    var readsMotionBlur: Bool {
        lock.withLock { isMotionBlurRead }
    }

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func markMotionBlur() {
        lock.withLock { isMotionBlurRead = true }
    }

    // MARK: - Private
}

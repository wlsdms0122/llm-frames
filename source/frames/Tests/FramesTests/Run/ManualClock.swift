//
//  ManualClock.swift
//  FramesTests
//
//  Created by JSilver on 11/25/26.
//

import Foundation

// A clock that moves only when it is told to, so a test knows every interval it times.
final class ManualClock: @unchecked Sendable {
    // MARK: - Property
    private let lock = NSLock()
    private var now: Double = 0

    var seconds: Double {
        lock.withLock { now }
    }

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func advance(by seconds: Double) {
        lock.withLock { now += seconds }
    }

    // MARK: - Private
}

//
//  RoleCallLog.swift
//  FramesTests
//
//  Created by JSilver on 11/17/26.
//

import Foundation

// The calls every recording role of one test was given, in the order they came.
final class RoleCallLog: @unchecked Sendable {
    // MARK: - Property
    private let lock = NSLock()
    private var recorded: [RoleCall] = []

    var calls: [RoleCall] {
        lock.withLock { recorded }
    }

    // MARK: - Initializer
    init() { }

    // MARK: - Public
    func record(_ call: RoleCall) {
        lock.withLock {
            recorded.append(call)
        }
    }

    // MARK: - Private
}

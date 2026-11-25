//
//  Locked.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

import Foundation

// A value read and written under a lock, from any thread.
package final class Locked<Value>: @unchecked Sendable {
    // MARK: - Property
    private let lock = NSLock()
    private var value: Value

    // MARK: - Initializer
    package init(_ value: Value) {
        self.value = value
    }

    // MARK: - Public
    package func read<Result>(_ body: (Value) -> Result) -> Result {
        lock.withLock { body(value) }
    }

    package func write<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.withLock { body(&value) }
    }

    // MARK: - Private
}

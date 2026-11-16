//
//  LoadWaiter.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/16/26.
//

import Foundation
import os

// Waits for AVFoundation's asynchronous loads, since the decoder is called synchronously, as resolve runs. The load
// runs on Swift's shared pool while the caller's thread is blocked.
struct LoadWaiter: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func value<Value: Sendable>(of load: @escaping @Sendable () async throws -> Value) throws -> Value {
        let semaphore = DispatchSemaphore(value: 0)
        let result = OSAllocatedUnfairLock<Result<Value, any Error>?>(initialState: nil)
        Task {
            let outcome: Result<Value, any Error>
            do {
                outcome = .success(try await load())
            } catch {
                outcome = .failure(error)
            }
            result.withLock { $0 = outcome }
            semaphore.signal()
        }
        semaphore.wait()

        return try result.withLock { $0! }.get()
    }

    // MARK: - Private
}

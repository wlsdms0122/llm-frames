//
//  OwnThreadTrait.swift
//  FramesTestMedia
//
//  Created by JSilver on 11/26/26.
//

import Testing

// Runs each test case of what it marks on a thread made for it, so a test that waits on AVFoundation, Metal or a
// semaphore holds no thread of Swift's shared pool, which swift-testing runs tests on and AVFoundation finishes its
// reads and writes on. Before macOS 15 a task cannot prefer an executor, and the test runs on the shared pool.
package struct OwnThreadTrait: SuiteTrait, TestTrait, TestScoping {
    // MARK: - Property
    package var isRecursive: Bool {
        true
    }

    // MARK: - Initializer
    // MARK: - Public
    // A suite, and a test of several cases, runs each of its cases on a thread of its own, so it takes none itself.
    package func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        guard testCase != nil, #available(macOS 15.0, *) else { return try await function() }

        let executor = ThreadExecutor()
        defer { executor.stop() }
        try await withTaskExecutorPreference(executor) {
            try await function()
        }
    }

    // MARK: - Private
}

extension Trait where Self == OwnThreadTrait {
    // MARK: - Property
    // Each test case runs on a thread of its own.
    package static var ownThread: Self {
        OwnThreadTrait()
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

//
//  BlockingTestLimit.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/26/26.
//

import Testing

// Runs each test of what it marks once a slot of `BlockingTestSlots` is free, waiting for one without holding a thread.
// swift-testing runs tests on Swift's shared pool, one thread per processor, and a test that waits on AVFoundation
// blocks its thread there, while AVFoundation's readers and writers finish their work on that same pool, so tests
// blocked on every thread of the pool hold one another up for minutes. Fewer tests than the pool has threads at once
// leave AVFoundation a thread.
struct BlockingTestLimit: SuiteTrait, TestTrait, TestScoping {
    // MARK: - Property
    var isRecursive: Bool {
        true
    }

    // MARK: - Initializer
    // MARK: - Public
    // A suite, and a test of several cases, runs its tests and cases each in its own slot, so it holds none itself.
    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        guard testCase != nil else { return try await function() }

        try await BlockingTestSlots.shared.run(function)
    }

    // MARK: - Private
}

extension Trait where Self == BlockingTestLimit {
    // MARK: - Property
    // Each test runs in a slot of the tests that may block their thread at once.
    static var blockingLimit: Self {
        BlockingTestLimit()
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

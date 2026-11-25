//
//  BlockingTestSlots.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/26/26.
//

import Foundation

// The slots of the tests that may block a thread of Swift's shared pool at once: half the processors, the pool's
// width, so at least half its threads stay free whatever the tests marked by `BlockingTestLimit` wait on. A test waits
// for a slot suspended, holding no thread, and slots pass to waiting tests in the order they asked.
actor BlockingTestSlots {
    // MARK: - Property
    static let shared = BlockingTestSlots(count: max(1, ProcessInfo.processInfo.activeProcessorCount / 2))

    private var free: Int
    private var waiting: [CheckedContinuation<Void, Never>] = []

    // MARK: - Initializer
    init(count: Int) {
        self.free = count
    }

    // MARK: - Public
    // Runs `body` in a slot, outside the actor, and frees the slot once it ends, thrown or not.
    nonisolated func run(_ body: @Sendable () async throws -> Void) async throws {
        await take()
        do {
            try await body()
        } catch {
            await give()
            throw error
        }
        await give()
    }

    // MARK: - Private
    private func take() async {
        guard free == 0 else {
            free -= 1
            return
        }

        await withCheckedContinuation { waiting.append($0) }
    }

    // A freed slot passes to the test that has waited longest, or is kept.
    private func give() {
        guard waiting.isEmpty else { return waiting.removeFirst().resume() }

        free += 1
    }
}

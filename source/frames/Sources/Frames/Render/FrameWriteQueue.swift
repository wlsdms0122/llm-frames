//
//  FrameWriteQueue.swift
//  Frames
//
//  Created by JSilver on 11/24/26.
//

import Foundation

// Appends each frame to every writer while the next frame is drawn. Each writer takes its frames in order on a queue
// of its own, and `append` waits while one frame is still being written, or two where the run's budget grants its
// `frames` the second's bytes until it is written (FRAMES-30 The budget), so the frames held at once are bounded. The
// budget counts each frame the queue holds as `frames`.
// The queues are serial, so Dispatch runs each on a thread outside the pool its concurrent queues share, which a writer
// waiting on AVFoundation would otherwise hold while AVFoundation finishes its work there. A slot is let go of on a
// serial queue too, since `append` waits for it on a caller's thread, which may be one of the threads the concurrent
// queues are given.
// A writer's failure stops every writer, and the next `append` or `finish` throws it. After `finish` or `cancel`
// returns, nothing of the queue holds a writer.
final class FrameWriteQueue: @unchecked Sendable {
    // MARK: - Property
    private let writers: [any VideoWriter]
    private let queues: [DispatchQueue]
    private let releases = DispatchQueue(label: "frames.render.writer.release")
    private let budget: MemoryBudget
    private let frameBytes: Int
    // The frame being written, which the floor of `frames` holds, and a frame waiting behind it where the budget grants
    // it room.
    private let slot = DispatchSemaphore(value: 1)
    private let grantedSlot = DispatchSemaphore(value: 1)
    private let lock = NSLock()
    private var failure: (any Error)?

    // MARK: - Initializer
    // Each frame is of `frameBytes`, which `budget` grants a second frame held.
    init(
        writers: [any VideoWriter],
        budget: MemoryBudget,
        frameBytes: Int
    ) {
        self.writers = writers
        self.queues = writers.indices.map { DispatchQueue(label: "frames.render.writer.\($0)") }
        self.budget = budget
        self.frameBytes = frameBytes
    }

    // MARK: - Public
    func append(_ frame: Pixels) throws {
        let release = holdSlot()
        if let failure = recorded() {
            release()
            throw failure
        }

        let group = DispatchGroup()
        for (writer, queue) in zip(writers, queues) {
            nonisolated(unsafe) let writer = writer
            queue.async(group: group) {
                guard self.recorded() == nil else { return }

                do {
                    try writer.append(frame)
                } catch {
                    self.record(error)
                }
            }
        }
        group.notify(queue: releases) { release() }
    }

    // Stops writing: frames not yet written are dropped, and the one being written is waited for.
    func cancel() {
        record(CancellationError())
        drain()
    }

    // Waits for every frame appended, then writes the rest of each file and closes it.
    func finish() throws {
        drain()
        if let failure = recorded() { throw failure }

        for writer in writers {
            try writer.finish()
        }
    }

    // MARK: - Private
    // Waits for a slot to hold a frame in, the second one where it is free and the budget grants the frame's bytes, and
    // gives what lets go of it.
    private func holdSlot() -> @Sendable () -> Void {
        if slot.wait(timeout: .now()) == .success {
            return heldSlot()
        }
        if grantedSlot.wait(timeout: .now()) == .success {
            if budget.take(frameBytes, for: .frames) {
                return { [grantedSlot, budget, frameBytes] in
                    budget.give(frameBytes, for: .frames)
                    grantedSlot.signal()
                }
            }
            grantedSlot.signal()
        }
        slot.wait()

        return heldSlot()
    }

    // The first slot, held: its frame lies within the floor of `frames`.
    private func heldSlot() -> @Sendable () -> Void {
        budget.hold(frameBytes, for: .frames)

        return { [slot, budget, frameBytes] in
            budget.give(frameBytes, for: .frames)
            slot.signal()
        }
    }

    private func drain() {
        for queue in queues {
            queue.sync {}
        }
    }

    private func recorded() -> (any Error)? {
        lock.withLock { failure }
    }

    private func record(_ error: any Error) {
        lock.withLock {
            if failure == nil { failure = error }
        }
    }
}

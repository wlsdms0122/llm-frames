//
//  FrameWriteQueue.swift
//  Frames
//
//  Created by JSilver on 11/24/26.
//

import Foundation

// Appends each frame to every writer while the next frame is drawn. Each writer takes its frames in order on a queue
// of its own, and `append` waits while `depth` frames are still being written, so the frames held at once are bounded.
// The queues are serial, so Dispatch runs each on a thread outside the 64 its concurrent queues share, which a writer
// waiting on AVFoundation would otherwise hold while AVFoundation finishes its work there.
// A writer's failure stops every writer, and the next `append` or `finish` throws it. After `finish` or `cancel`
// returns, nothing of the queue holds a writer.
final class FrameWriteQueue: @unchecked Sendable {
    // MARK: - Property
    // The frames held by the writers at once, written and waiting.
    static let depth = 2

    private let writers: [any VideoWriter]
    private let queues: [DispatchQueue]
    private let slots = DispatchSemaphore(value: FrameWriteQueue.depth)
    private let lock = NSLock()
    private var failure: (any Error)?

    // MARK: - Initializer
    init(writers: [any VideoWriter]) {
        self.writers = writers
        self.queues = writers.indices.map { DispatchQueue(label: "frames.render.writer.\($0)") }
    }

    // MARK: - Public
    func append(_ frame: Pixels) throws {
        slots.wait()
        if let failure = recorded() {
            slots.signal()
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
        group.notify(queue: .global()) { [slots] in slots.signal() }
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

//
//  PictureLookahead.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/25/26.
//

import Foundation
import Frames
import os

// Reads a video's next picture while its caller works on the one it has, for a caller that reads a file's frames
// forward by a steady step, as a render reads a clip. Frames are kept apart for each file and reading. Once two frames
// of one file and reading are read, the second forward of the first, the frame as far on again from the second is read
// ahead on a thread made for that read by the same read, so it holds the same bits, while fewer frames than the machine
// has processors are being read ahead, so at most as many as it has are read ahead at once, and while the run's budget
// grants its `readAhead` the frame's bytes until the frame is given or let go of (FRAMES-30); past either the frame is
// read where it is asked. AVFoundation finishes a read's work on Swift's shared pool and on the pool of threads
// Dispatch runs its concurrent queues on, as many as the system's `kern.wq_max_constrained_threads`, 64 on macOS 27.2,
// and itself holds one thread of that pool waiting for each read it makes sample data ready for, so reads on threads of
// either pool, or as many reads at once on any threads as that pool has threads, hold every thread that work needs
// (FRAMES-21 Rules). The threads made here are of neither pool. A frame asked for that is not the one read ahead is
// read where it is asked, once every frame of the same file being read ahead is read, so the file's reader is where
// those reads left it. A read ahead that fails is dropped, so its frame is read again where it is asked and fails
// there. `read` is told whether it reads ahead, and the time callers wait on a frame being read ahead is kept as
// `waitingSeconds` (FRAMES-23 Runs).
final class PictureLookahead: Sendable {
    // MARK: - Property
    private static let readsAtOnce = ProcessInfo.processInfo.activeProcessorCount

    private let budget: MemoryBudget
    private let entries = OSAllocatedUnfairLock<[Entry]>(initialState: [])
    private let readsAhead = OSAllocatedUnfairLock<Int>(initialState: 0)
    private let waiting = OSAllocatedUnfairLock<Double>(initialState: 0)

    // The seconds callers have waited on frames being read ahead, summed over the callers' threads.
    var waitingSeconds: Double {
        waiting.withLock { $0 }
    }

    // MARK: - Initializer
    init(budget: MemoryBudget) {
        self.budget = budget
    }

    // MARK: - Public
    // Frame `index` of the file at `path`, of `count` frames, as `read` reads it, each picture of `bytes`.
    func picture(
        atFrame index: Int,
        of path: String,
        count: Int,
        bytes: Int,
        reading: PictureReading,
        read: @escaping @Sendable (_ index: Int, _ isAhead: Bool) throws -> Pixels
    ) throws -> Pixels {
        let (entry, pending) = entries.withLock { entries in
            (
                entries.first { $0.path == path && $0.reading == reading },
                entries.filter { $0.path == path }.compactMap(\.ahead)
            )
        }
        let picture: Pixels
        if let ahead = entry?.ahead, ahead.index == index, let readAhead = wait(for: ahead) {
            picture = readAhead
        } else {
            for ahead in pending {
                _ = wait(for: ahead)
            }
            picture = try read(index, false)
        }

        let ahead = entry.flatMap { entry -> ReadAhead? in
            let next = index + (index - entry.index)
            guard index > entry.index, next < count else { return nil }

            return readsAhead.withLock { [budget] reads in
                guard reads < Self.readsAtOnce, budget.take(bytes, for: .readAhead) else { return nil }
                reads += 1

                return ReadAhead(index: next, bytes: bytes)
            }
        }
        let replaced = entries.withLock { entries in
            let replaced = entries.filter { $0.path == path && $0.reading == reading }
            entries.removeAll { $0.path == path && $0.reading == reading }
            entries.append(Entry(path: path, reading: reading, index: index, ahead: ahead))

            return replaced
        }
        for ahead in replaced.compactMap(\.ahead) where ahead.letGo() {
            budget.give(ahead.bytes, for: .readAhead)
        }
        if let ahead {
            let thread = Thread { [readsAhead] in
                ahead.finish(try? read(ahead.index, true))
                readsAhead.withLock { $0 -= 1 }
            }
            thread.qualityOfService = .userInitiated
            thread.start()
        }

        return picture
    }

    // MARK: - Private
    // The picture of a frame being read ahead once its read ends, the time waited for it kept, and its bytes given
    // back to the budget, since the picture is the caller's once it is given.
    private func wait(for ahead: ReadAhead) -> Pixels? {
        let start = ContinuousClock.now
        defer {
            let waited = (ContinuousClock.now - start).seconds
            waiting.withLock { $0 += waited }
        }

        let picture = ahead.picture()
        if ahead.letGo() { budget.give(ahead.bytes, for: .readAhead) }

        return picture
    }
}

extension PictureLookahead {
    // The frame read last of a file and reading, and the frame being read ahead of it, which is none when the step
    // from the frame before it is not forward or leads past the last frame, when as many frames as are read ahead at
    // once were being read ahead, or when the budget granted no room for it.
    private struct Entry: Sendable {
        let path: String
        let reading: PictureReading
        let index: Int
        let ahead: ReadAhead?
    }

    // A frame being read ahead, of `bytes`: `picture()` waits for its read and gives the picture, or nil where the read
    // failed, and `letGo()` is true once, for whoever lets go of the frame first, its caller or the read that replaces
    // it.
    private final class ReadAhead: Sendable {
        // MARK: - Property
        let index: Int
        let bytes: Int
        private let done = DispatchSemaphore(value: 0)
        private let result = OSAllocatedUnfairLock<Pixels?>(initialState: nil)
        private let isHeld = OSAllocatedUnfairLock<Bool>(initialState: true)

        // MARK: - Initializer
        init(
            index: Int,
            bytes: Int
        ) {
            self.index = index
            self.bytes = bytes
        }

        // MARK: - Public
        func letGo() -> Bool {
            isHeld.withLock { isHeld in
                defer { isHeld = false }

                return isHeld
            }
        }

        func finish(_ picture: Pixels?) {
            result.withLock { $0 = picture }
            done.signal()
        }

        func picture() -> Pixels? {
            done.wait()
            done.signal()

            return result.withLock { $0 }
        }

        // MARK: - Private
    }
}

//
//  PictureLookahead.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/25/26.
//

import Foundation
import Frames
import os

// Reads a video's frames its caller tells it it asks next while the caller works on the frames it has, for a caller
// that reads a file's frames one after another, as a render reads a clip. Frames are kept apart for each play of a file
// and reading (FRAMES-21 Rules). Each frame told is read ahead on a thread made for that read by the same read, so it
// holds the same bits, once the frames of the same play told before it are read, so a play's reads ahead reach its
// reader in the order told, while fewer frames than the machine has processors are being read ahead, so at most as many
// as it has are read ahead at once, and while the run's budget grants its `readAhead` the frame's bytes until the frame
// is given or let go of (FRAMES-30); past either, that frame and those told after it with it are read where they are
// asked. AVFoundation finishes a read's work on Swift's shared pool and on the pool of threads Dispatch runs its
// concurrent queues on, as many as the system's `kern.wq_max_constrained_threads`, 64 on macOS 27.2, and itself holds
// one thread of that pool waiting for each read it makes sample data ready for, so reads on threads of either pool, or
// as many reads at once on any threads as that pool has threads, hold every thread that work needs (FRAMES-21 Rules).
// The threads made here are of neither pool. A frame asked for that is not one being read ahead is read where it is
// asked, once every frame of the same play being read ahead is read, so the play's reader is where those reads left
// it. A read ahead that fails is dropped, so its frame is read again where it is asked and fails there. A telling for a
// play and reading lets go of the frames read ahead for them that it does not name. Once a frame is rendered, the
// frames read ahead for it that it did not ask are let go of, and the plays the decoder keeps no longer are over and
// their entries dropped (FRAMES-21 Rules). The time callers wait on a frame being read ahead is kept as
// `waitingSeconds` (FRAMES-23 Runs).
final class PictureLookahead: Sendable {
    // MARK: - Property
    // As many as the machine has processors, and at most 32 whatever their number, so reads ahead never hold more
    // than half of the system's pool of threads where it has 64, as on macOS 27.2.
    private static let readsAtOnce = min(ProcessInfo.processInfo.activeProcessorCount, 32)

    private let budget: MemoryBudget
    private let state = OSAllocatedUnfairLock<LookaheadState>(initialState: LookaheadState())
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
    // Frame `index` of `play` as `read` reads it: the frame read ahead for the play and reading where one is, and read
    // where it is asked otherwise.
    func picture(
        atFrame index: Int,
        of play: VideoPlay,
        reading: PictureReading,
        read: (_ index: Int) throws -> Pixels
    ) throws -> Pixels {
        let (entry, last) = state.withLock { state in
            let entry = state.entries.first { $0.play == play && $0.reading == reading && $0.ahead.index == index }
            state.entries.removeAll { $0.play == play && $0.reading == reading && $0.ahead.index == index }

            return (entry, state.lastReads[play])
        }
        if let entry, let picture = take(entry.ahead) { return picture }

        if let last { measureWaiting { last.wait() } }

        return try read(index)
    }

    // Reads frames `indices` of `play`, read as `reading`, ahead, in that order, each a picture of `bytes`, by `read`,
    // and lets go of the frames read ahead for the play and reading that `indices` does not name. A frame told that is
    // already being read ahead for them stays, told for the frame being rendered.
    func readAhead(
        atFrames indices: [Int],
        of play: VideoPlay,
        reading: PictureReading,
        bytes: Int,
        read: @escaping @Sendable (_ index: Int) throws -> Pixels
    ) {
        let (started, replaced, before) = state.withLock { [budget] state in
            let held = state.entries.filter { $0.play == play && $0.reading == reading }
            let replaced = held.filter { !indices.contains($0.ahead.index) }.map(\.ahead)
            state.entries.removeAll { $0.play == play && $0.reading == reading && !indices.contains($0.ahead.index) }
            for index in state.entries.indices
            where state.entries[index].play == play && state.entries[index].reading == reading {
                state.entries[index].rendered = state.rendered
            }

            var started: [ReadAhead] = []
            for index in indices where !held.contains(where: { $0.ahead.index == index }) {
                let isAdmitted = readsAhead.withLock { reads in
                    guard reads < Self.readsAtOnce, budget.take(bytes, for: .readAhead) else { return false }
                    reads += 1

                    return true
                }
                guard isAdmitted else { break }

                let ahead = ReadAhead(index: index, bytes: bytes)
                state.entries.append(Entry(play: play, reading: reading, rendered: state.rendered, ahead: ahead))
                started.append(ahead)
            }
            let before = state.lastReads[play]
            if let last = started.last { state.lastReads[play] = last }

            return (started, replaced, before)
        }
        for ahead in replaced {
            letGo(of: ahead)
        }

        var previous = before
        for ahead in started {
            let thread = Thread { [readsAhead, previous] in
                previous?.wait()
                ahead.finish(try? read(ahead.index))
                readsAhead.withLock { $0 -= 1 }
            }
            thread.qualityOfService = .userInitiated
            thread.start()
            previous = ahead
        }
    }

    // Ends the frame being rendered: lets go of the frames read ahead for it that it did not ask, and ends the plays
    // not among `plays`, the plays the decoder keeps, once their frames being read ahead are read, so no read of them
    // goes on after, their bytes given back.
    func frameRendered(keeping plays: Set<VideoPlay>) {
        let (dropped, over) = state.withLock { state -> ([ReadAhead], [ReadAhead]) in
            let rendered = state.rendered
            let isDropped = { (entry: Entry) in !plays.contains(entry.play) || entry.rendered < rendered }
            let dropped = state.entries.filter(isDropped).map(\.ahead)
            state.entries.removeAll(where: isDropped)
            let over = state.lastReads.filter { !plays.contains($0.key) }.map(\.value)
            state.lastReads = state.lastReads.filter { plays.contains($0.key) }
            state.rendered += 1

            return (dropped, over)
        }
        for ahead in dropped {
            letGo(of: ahead)
        }
        for ahead in over {
            measureWaiting { ahead.wait() }
        }
    }

    // MARK: - Private
    // The picture of a frame being read ahead once its read ends, nil where the read failed, its bytes given back to
    // the budget, since the picture is the caller's once it is given.
    private func take(_ ahead: ReadAhead) -> Pixels? {
        let picture = measureWaiting { ahead.take() }
        budget.give(ahead.bytes, for: .readAhead)

        return picture
    }

    // Lets go of a frame being read ahead, its bytes given back to the budget.
    private func letGo(of ahead: ReadAhead) {
        ahead.letGo()
        budget.give(ahead.bytes, for: .readAhead)
    }

    // Keeps the time waited in `wait` as time callers waited on frames being read ahead.
    private func measureWaiting<Value>(_ wait: () -> Value) -> Value {
        let start = ContinuousClock.now
        defer {
            let waited = (ContinuousClock.now - start).seconds
            waiting.withLock { $0 += waited }
        }

        return wait()
    }
}

extension PictureLookahead {
    // The frames being read ahead and not yet given or let go of, the frame each play's reads ahead reach its reader
    // with last, which the next read ahead of the play and a read of it where it is asked wait for, and the frames
    // rendered so far.
    private struct LookaheadState: Sendable {
        var entries: [Entry] = []
        var lastReads: [VideoPlay: ReadAhead] = [:]
        var rendered = 0
    }

    // A frame being read ahead for a play of a file and reading, told while frame `rendered` of the run was being
    // rendered.
    private struct Entry: Sendable {
        let play: VideoPlay
        let reading: PictureReading
        var rendered: Int
        let ahead: ReadAhead
    }

    // A frame being read ahead, of `bytes`: `wait()` waits for its read, `take()` waits for it and gives the picture,
    // nil where the read failed, and `letGo()` drops the picture, and the one its read ends with where it is still
    // going. Whoever takes an entry out of the lookahead's entries takes the frame or lets go of it, once.
    private final class ReadAhead: Sendable {
        // MARK: - Property
        let index: Int
        let bytes: Int
        private let done = DispatchSemaphore(value: 0)
        private let result = OSAllocatedUnfairLock<(picture: Pixels?, isHeld: Bool)>(
            initialState: (picture: nil, isHeld: true)
        )

        // MARK: - Initializer
        init(
            index: Int,
            bytes: Int
        ) {
            self.index = index
            self.bytes = bytes
        }

        // MARK: - Public
        func wait() {
            done.wait()
            done.signal()
        }

        func take() -> Pixels? {
            wait()

            return result.withLock { result in
                defer { result = (picture: nil, isHeld: false) }

                return result.picture
            }
        }

        func letGo() {
            result.withLock { $0 = (picture: nil, isHeld: false) }
        }

        func finish(_ picture: Pixels?) {
            result.withLock { result in
                if result.isHeld { result.picture = picture }
            }
            done.signal()
        }

        // MARK: - Private
    }
}

//
//  ReaderBound.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/26/26.
//

import Foundation
import os

// The videos the decoder keeps a reader open on, at most `count` of them and of at most `memory` bytes together, each
// at the cost it is admitted with (FRAMES-21 Rules). A video read with no reader open takes one where the bound
// leaves room, and otherwise closes others first, one at a time: the one read longest ago of those holding frames
// read in a turn, else the one read longest ago where that read came before the asking video's read before this one,
// so it was not read since, else the one read last, so videos read in a cycle past the bound keep the rest of their
// readers. A video whose reader the bound closed takes a turn when it is read again. One reader is open whatever its
// cost. Used from any thread.
final class ReaderBound: Sendable {
    // MARK: - Property
    private let count: Int
    private let memory: Int
    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    // MARK: - Initializer
    init(
        count: Int,
        memory: Int
    ) {
        self.count = count
        self.memory = memory
    }

    // MARK: - Public
    // Records a read of the video at `path` by its reader, which holds `cost` bytes while it is open, and gives the
    // videos whose readers to close and whether the read is a turn. `holdsFrames` tells whether a video holds frames
    // read in a turn.
    func admit(
        _ path: String,
        cost: Int,
        holdsFrames: (String) -> Bool
    ) -> (closing: [String], isTurn: Bool) {
        state.withLockUnchecked { state in
            state.tick += 1
            let previous = state.lastRead[path]
            state.lastRead[path] = state.tick
            if state.open[path] != nil { return ([], false) }

            var closing: [String] = []
            while !state.open.isEmpty, state.open.count + 1 > count || state.used + cost > memory {
                let readers = state.open.keys.sorted { state.lastRead[$0, default: 0] < state.lastRead[$1, default: 0] }
                let holding = readers.first(where: holdsFrames)
                let stale = readers.first.flatMap { first in
                    previous.map { state.lastRead[first, default: 0] < $0 } ?? true ? first : nil
                }
                guard let closed = holding ?? stale ?? readers.last else { break }

                state.used -= state.open.removeValue(forKey: closed) ?? 0
                state.closed.insert(closed)
                closing.append(closed)
            }
            state.open[path] = cost
            state.used += cost

            return (closing, state.closed.remove(path) != nil)
        }
    }

    // MARK: - Private
}

extension ReaderBound {
    // The open readers and their costs, the bytes they hold together, the count of reads so far, the count at each
    // video's last read, and the videos whose readers the bound closed and that were not read since.
    private struct State: Sendable {
        var open: [String: Int] = [:]
        var used = 0
        var tick = 0
        var lastRead: [String: Int] = [:]
        var closed: Set<String> = []
    }
}

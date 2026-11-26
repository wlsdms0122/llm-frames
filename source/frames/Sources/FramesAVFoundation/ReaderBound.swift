//
//  ReaderBound.swift
//  FramesAVFoundation
//
//  Created by JSilver on 11/26/26.
//

import Foundation
import Frames
import os

// The readers the decoder keeps open, each named by a `Reader`, one for each play of a video, at most `count` of them,
// and together no more than the run's budget grants its `readers`, each at the cost it is admitted with (FRAMES-21
// Rules, FRAMES-30 The budget). The budget's floor for readers is raised to each reader admitted, so one reader of the
// costliest video read is the floor. A reader read with none open takes one where the bound leaves room, and
// otherwise closes others first, one at a time: the one read longest ago of those holding frames read in a turn, else
// the one read longest ago where that read came before the asking reader's read before this one, so it was not read
// since, else the one read last, so readers read in a cycle past the bound keep the rest of their readers open. A
// reader the bound closed takes a turn when it is read again, and is admitted with the budget's room for the frames its
// turn holds, for which it closes others in the same order as for its reader, since a turn whose frames are not held
// opens a reader again for each frame. One reader is open whatever the budget holds, since it lies within the floor.
// Used from any thread.
final class ReaderBound<Reader: Hashable & Sendable>: Sendable {
    // MARK: - Property
    private let count: Int
    private let budget: MemoryBudget
    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    // MARK: - Initializer
    init(
        count: Int,
        budget: MemoryBudget
    ) {
        self.count = count
        self.budget = budget
    }

    // MARK: - Public
    // Records a read by `reader`, which the budget charges `cost` bytes while it is open, and gives the readers to
    // close and, for a read that is a turn, the bytes the budget granted its `turns` for the frames the turn holds, nil
    // for a read that is not one: `turnRoom` where it fits with other readers closed for it, and 0 where it does not fit
    // with every other reader closed. `holdsFrames` tells whether a reader holds frames read in a turn. Refuses a limit
    // under the floor the reader raises.
    func admit(
        _ reader: Reader,
        cost: Int,
        turnRoom: Int,
        holdsFrames: (Reader) -> Bool
    ) throws -> (closing: [Reader], turnRoom: Int?) {
        try state.withLockUnchecked { state in
            state.tick += 1
            let previous = state.lastRead[reader]
            state.lastRead[reader] = state.tick
            if state.open[reader] != nil { return ([], nil) }

            budget.require(cost, for: .readers)
            try budget.checkFloor()

            let isTurn = state.closed.remove(reader) != nil
            var hasReader = false
            var hasRoom = !isTurn
            // Whether the reader and a turn's room are granted, each asked for until it is.
            let isGranted = { [budget] in
                hasReader = hasReader || budget.take(cost, for: .readers)
                hasRoom = hasRoom || hasReader && budget.take(turnRoom, for: .turns)

                return hasReader && hasRoom
            }
            var closing: [Reader] = []
            while !state.open.isEmpty, state.open.count + 1 > count || !isGranted() {
                let readers = state.open.keys.sorted { state.lastRead[$0, default: 0] < state.lastRead[$1, default: 0] }
                let holding = readers.first(where: holdsFrames)
                let stale = readers.first.flatMap { first in
                    previous.map { state.lastRead[first, default: 0] < $0 } ?? true ? first : nil
                }
                guard let closed = holding ?? stale ?? readers.last else { break }

                budget.give(state.open.removeValue(forKey: closed) ?? 0, for: .readers)
                state.closed.insert(closed)
                closing.append(closed)
            }
            if !hasReader { _ = budget.take(cost, for: .readers) }
            if !hasRoom { hasRoom = budget.take(turnRoom, for: .turns) }
            state.open[reader] = cost

            return (closing, isTurn ? (hasRoom ? turnRoom : 0) : nil)
        }
    }

    // Whether `reader` is open, admitted by the bound and not closed since.
    func isOpen(_ reader: Reader) -> Bool {
        state.withLock { $0.open[reader] != nil }
    }

    // MARK: - Private
}

extension ReaderBound {
    // The open readers and their costs, the count of reads so far, the count at each reader's last read, and the
    // readers the bound closed that were not read since.
    private struct State: Sendable {
        var open: [Reader: Int] = [:]
        var tick = 0
        var lastRead: [Reader: Int] = [:]
        var closed: Set<Reader> = []
    }
}

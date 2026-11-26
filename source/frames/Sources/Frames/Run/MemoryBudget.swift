//
//  MemoryBudget.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

import os

// A run's memory limit as one budget its holders draw from (FRAMES-30 The budget). A holder has a floor, the least it
// holds for the run to work, and the budget counts each holder at the larger of its floor and what it holds. A holder
// is granted more past its floor only where the total, with the correction, stays within the limit, and holding less
// is always granted. The correction is what the process holds past what the budget counts in it, read from `meter` at
// each such grant (FRAMES-30 What it measures). The run raises each floor as it learns it and checks the floors against
// the limit before the first frame, by the floors alone. Used from any thread.
package final class MemoryBudget: Sendable {
    // MARK: - Property
    package let limit: MemorySize

    private let meter: any MemoryMeter
    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    // What the budget has seen so far.
    package var usage: MemoryUsage {
        let state = state.withLock { $0 }
        let holders = MemoryHolder.allCases.map { holder in
            let account = state[holder]
            return MemoryHolderUsage(holder: holder, floor: account.floor, peak: account.peak, refused: account.refused)
        }

        return MemoryUsage(
            limit: limit.bytes,
            floor: holders.reduce(0) { $0 + $1.floor },
            peak: state.peak,
            process: meter.read().peak,
            uncounted: state.correction.peak,
            holders: holders
        )
    }

    // MARK: - Initializer
    package init(
        limit: MemorySize,
        meter: any MemoryMeter = ProcessMemoryMeter()
    ) {
        self.limit = limit
        self.meter = meter
    }

    // MARK: - Public
    // Raises `holder`'s floor to `bytes` where it is lower.
    package func require(
        _ bytes: Int,
        for holder: MemoryHolder
    ) {
        update { state in
            state[holder].floor = max(state[holder].floor, bytes)
        }
    }

    // Refuses a limit under the sum of the floors, naming each holder's.
    package func checkFloor() throws {
        let usage = usage
        guard usage.floor <= limit.bytes else { throw MemoryError.underFloor(limit: limit, floors: usage.holders) }
    }

    // `holder` holds `bytes` more where it stays within its floor, or where the total with the correction stays within
    // the limit, the correction taken with a reading of the process's memory, and gives whether it does. A refusal is
    // counted for the holder.
    package func take(
        _ bytes: Int,
        for holder: MemoryHolder
    ) -> Bool {
        update { state in
            var account = state[holder]
            account.held += bytes
            let grown = account.counted - state[holder].counted
            guard grown > 0 else {
                state[holder] = account
                return true
            }

            let reading = meter.read()
            state.correction.record(reading.footprint - state.total(in: .process), at: reading.time)
            guard state.total + state.correction.bytes + grown <= limit.bytes else {
                state[holder].refused += 1
                return false
            }

            state[holder] = account
            return true
        }
    }

    // `holder` holds `bytes` more whatever the total, for memory the run cannot go on without, which a holder that
    // does not give way holds within the floor it is given before the first frame.
    package func hold(
        _ bytes: Int,
        for holder: MemoryHolder
    ) {
        update { state in
            state[holder].held += bytes
        }
    }

    // `holder` holds `bytes` less.
    package func give(
        _ bytes: Int,
        for holder: MemoryHolder
    ) {
        update { state in
            state[holder].held -= bytes
        }
    }

    // MARK: - Private
    // Runs `change` on the state and records the peaks it leaves.
    private func update<Result>(_ change: (inout State) -> Result) -> Result {
        state.withLockUnchecked { state in
            let result = change(&state)
            for holder in MemoryHolder.allCases {
                state[holder].peak = max(state[holder].peak, state[holder].counted)
            }
            state.peak = max(state.peak, state.total)

            return result
        }
    }
}

extension MemoryBudget {
    // Each holder's account, the largest total counted at once, and the correction.
    private struct State: Sendable {
        var accounts: [MemoryHolder: Account] = [:]
        var peak = 0
        var correction = MemoryCorrection()

        // The sum of what the budget counts each holder at.
        var total: Int {
            accounts.values.reduce(0) { $0 + $1.counted }
        }

        // The sum of what the budget counts the holders whose memory lies in `place` at.
        func total(in place: MemoryPlace) -> Int {
            accounts.filter { $0.key.place == place }.values.reduce(0) { $0 + $1.counted }
        }

        subscript(holder: MemoryHolder) -> Account {
            get { accounts[holder] ?? Account() }
            set { accounts[holder] = newValue }
        }
    }

    // A holder's floor, what it holds, the most the budget counted it at, and the times it was refused more.
    private struct Account: Sendable {
        var floor = 0
        var held = 0
        var peak = 0
        var refused = 0

        // What the budget counts the holder at.
        var counted: Int {
            max(floor, held)
        }
    }
}

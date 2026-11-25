//
//  MemoryBudget.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

import os

// A run's memory limit as one budget its holders draw from (FRAMES-30 The budget). A holder has a floor, the least it
// holds for the run to work, and the budget counts each holder at the larger of its floor and what it holds. A holder
// is granted more only where the total stays within the limit, and holding less is always granted. The run raises each
// floor as it learns it and checks the floors against the limit before the first frame. Used from any thread.
package final class MemoryBudget: Sendable {
    // MARK: - Property
    package let limit: MemorySize

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
            holders: holders
        )
    }

    // MARK: - Initializer
    package init(limit: MemorySize) {
        self.limit = limit
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

    // `holder` holds `bytes` more where it stays within its floor or the total stays within the limit, and gives
    // whether it does. A refusal is counted for the holder.
    package func take(
        _ bytes: Int,
        for holder: MemoryHolder
    ) -> Bool {
        update { state in
            var account = state[holder]
            account.held += bytes
            let grown = account.counted - state[holder].counted
            guard grown <= 0 || state.total + grown <= limit.bytes else {
                state[holder].refused += 1
                return false
            }

            state[holder] = account
            return true
        }
    }

    // `holder` holds `bytes` more whatever the total, for memory the run cannot go on without, which the holders that
    // give way then find no room in.
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
    // Each holder's account, and the largest total counted at once.
    private struct State: Sendable {
        var accounts: [MemoryHolder: Account] = [:]
        var peak = 0

        // The sum of what the budget counts each holder at.
        var total: Int {
            accounts.values.reduce(0) { $0 + $1.counted }
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

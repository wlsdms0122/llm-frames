//
//  MemoryBudget+Counted.swift
//  FramesAVFoundationTests
//
//  Created by JSilver on 11/26/26.
//

import Frames

// What a budget of a finite limit counts its holders at, as a test reads it through the budget's grants alone.
extension MemoryBudget {
    // MARK: - Property
    // The bytes the budget counts its holders at now, each at the larger of its floor and what it holds: the limit less
    // the most it still grants `frames`, found by halving, each grant given back. `frames` holds nothing and has no
    // floor where the decoder's parts draw from the budget, since only the encoder's queue holds it.
    var counted: Int {
        var granted = 0
        var refused = limit.bytes + 1
        while refused - granted > 1 {
            let bytes = granted + (refused - granted) / 2
            if take(bytes, for: .frames) {
                give(bytes, for: .frames)
                granted = bytes
            } else {
                refused = bytes
            }
        }

        return limit.bytes - granted
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

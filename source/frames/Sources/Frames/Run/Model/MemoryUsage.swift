//
//  MemoryUsage.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

// What a run's budget saw: its limit, the run's floor, the largest total it counted at once, the process's largest
// footprint, the most the process held past what the budget counted in it at a reading, all in bytes, and each holder
// in `MemoryHolder`'s order (FRAMES-30 Report).
package struct MemoryUsage: Equatable, Sendable {
    // MARK: - Property
    package let limit: Int
    package let floor: Int
    package let peak: Int
    package let process: Int
    package let uncounted: Int
    package let holders: [MemoryHolderUsage]

    // MARK: - Initializer
    package init(
        limit: Int,
        floor: Int,
        peak: Int,
        process: Int,
        uncounted: Int,
        holders: [MemoryHolderUsage]
    ) {
        self.limit = limit
        self.floor = floor
        self.peak = peak
        self.process = process
        self.uncounted = uncounted
        self.holders = holders
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  MemoryUsage.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

// What a run's budget saw: its limit, the run's floor, the largest total it counted at once, all in bytes, and each
// holder in `MemoryHolder`'s order (FRAMES-30 Report).
package struct MemoryUsage: Equatable, Sendable {
    // MARK: - Property
    package let limit: Int
    package let floor: Int
    package let peak: Int
    package let holders: [MemoryHolderUsage]

    // MARK: - Initializer
    package init(
        limit: Int,
        floor: Int,
        peak: Int,
        holders: [MemoryHolderUsage]
    ) {
        self.limit = limit
        self.floor = floor
        self.peak = peak
        self.holders = holders
    }

    // MARK: - Public
    // MARK: - Private
}

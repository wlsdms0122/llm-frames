//
//  MemoryReading.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

// One reading of the process's memory: its physical footprint, the largest footprint it has held over its life, both
// in bytes, and when it was read.
package struct MemoryReading: Equatable, Sendable {
    // MARK: - Property
    package let footprint: Int
    package let peak: Int
    package let time: ContinuousClock.Instant

    // MARK: - Initializer
    package init(
        footprint: Int,
        peak: Int,
        time: ContinuousClock.Instant
    ) {
        self.footprint = footprint
        self.peak = peak
        self.time = time
    }

    // MARK: - Public
    // MARK: - Private
}

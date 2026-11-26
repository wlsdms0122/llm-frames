//
//  MemoryHolderUsage.swift
//  Frames
//
//  Created by JSilver on 11/26/26.
//

// What a run's budget saw of one holder: its floor and the most it counted the holder at, in bytes, and the times it
// refused the holder more (FRAMES-30 Report).
package struct MemoryHolderUsage: Equatable, Sendable {
    // MARK: - Property
    package let holder: MemoryHolder
    package let floor: Int
    package let peak: Int
    package let refused: Int

    // MARK: - Initializer
    package init(
        holder: MemoryHolder,
        floor: Int,
        peak: Int,
        refused: Int
    ) {
        self.holder = holder
        self.floor = floor
        self.peak = peak
        self.refused = refused
    }

    // MARK: - Public
    // MARK: - Private
}

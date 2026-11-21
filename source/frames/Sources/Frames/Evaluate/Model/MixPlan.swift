//
//  MixPlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// The sound of a whole sequence as a tree of buses: `length` samples per channel at `sampleRate` from sequence time 0,
// its segments and buses in audio entry order, the repeats of a loop in time order, and `filter`, the sequence's chain,
// which runs over their sum. Segments and buses that overlap are mixed.
package struct MixPlan: Equatable, Sendable {
    // MARK: - Property
    package static let sampleRate = 48000

    package let length: Int
    package let segments: [MixSegment]
    package let buses: [MixBus]
    package let filter: [MixFilterEntry]

    // MARK: - Initializer
    package init(
        length: Int,
        segments: [MixSegment],
        buses: [MixBus] = [],
        filter: [MixFilterEntry] = []
    ) {
        self.length = length
        self.segments = segments
        self.buses = buses
        self.filter = filter
    }

    // MARK: - Public
    // MARK: - Private
}

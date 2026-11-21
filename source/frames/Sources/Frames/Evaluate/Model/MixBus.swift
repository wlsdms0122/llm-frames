//
//  MixBus.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The bus of a compound clip or a template instance, or of one repeat of a looped one, heard from sequence time `start`
// to `end`, its span. It sums its segments and its buses in audio entry order, runs `filter`, its chain, over the sum,
// the nested sequence's entries first and then the compound clip's own, and multiplies the result by `envelope`, its
// level. The envelope's points are in sequence time from `start` to `end`, joined in straight lines.
package struct MixBus: Equatable, Sendable {
    // MARK: - Property
    package let start: Double
    package let end: Double
    package let segments: [MixSegment]
    package let buses: [MixBus]
    package let filter: [MixFilterEntry]
    package let envelope: [EnvelopePoint]

    // MARK: - Initializer
    package init(
        start: Double,
        end: Double,
        segments: [MixSegment],
        buses: [MixBus] = [],
        filter: [MixFilterEntry] = [],
        envelope: [EnvelopePoint]
    ) {
        self.start = start
        self.end = end
        self.segments = segments
        self.buses = buses
        self.filter = filter
        self.envelope = envelope
    }

    // MARK: - Public
    // MARK: - Private
}

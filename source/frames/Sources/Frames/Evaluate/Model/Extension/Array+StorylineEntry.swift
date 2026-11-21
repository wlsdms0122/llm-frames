//
//  Array+StorylineEntry.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// A storyline entry's drawn range, which reaches into the transitions at its two ends, one of them written on the next
// entry, and the time the entry's values are read at in a sample, by its own switch and held in that range
// (FRAMES-29).
extension Array where Element == ResolvedStorylineClip {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func drawnRange(ofEntry index: Int) -> TimeRange {
        let entry = self[index]
        let outgoing = indices.contains(index + 1) ? self[index + 1].transition : nil

        return TimeRange(
            drawing: TimeRange(start: entry.start, end: entry.end),
            incoming: entry.transition.map { TimeRange(start: $0.start, end: $0.end) },
            outgoing: outgoing.map { TimeRange(start: $0.start, end: $0.end) }
        )
    }

    func valueTime(
        ofEntry index: Int,
        in sample: SampleInstant
    ) -> SampleTime {
        sample.readTime(ownedBy: self[index].isMotionBlurred, in: drawnRange(ofEntry: index))
    }

    // MARK: - Private
}

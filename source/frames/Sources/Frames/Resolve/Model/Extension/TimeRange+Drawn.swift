//
//  TimeRange+Drawn.swift
//  Frames
//
//  Created by JSilver on 11/21/26.
//

// The range a storyline entry draws in: its edit range, widened by the transition that brings it in and the one that
// takes it out (FRAMES-8).
extension TimeRange {
    // MARK: - Property
    // MARK: - Initializer
    init(
        drawing edit: TimeRange,
        incoming: TimeRange?,
        outgoing: TimeRange?
    ) {
        self.init(start: min(edit.start, incoming?.start ?? edit.start), end: max(edit.end, outgoing?.end ?? edit.end))
    }

    // MARK: - Public
    // MARK: - Private
}

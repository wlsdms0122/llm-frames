//
//  TimelineReport.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What `timeline` prints: for every storyline clip its ranges, speed and incoming transition, and for every other
// clip its visible range, kind, lane, parent and animation.
struct TimelineReport: Equatable, Sendable {
    // MARK: - Property
    let duration: Double
    let storyline: [TimelineStorylineEntry]
    let clips: [TimelineClipEntry]

    // MARK: - Initializer
    init(
        duration: Double,
        storyline: [TimelineStorylineEntry],
        clips: [TimelineClipEntry]
    ) {
        self.duration = duration
        self.storyline = storyline
        self.clips = clips
    }

    // MARK: - Public
    // MARK: - Private
}

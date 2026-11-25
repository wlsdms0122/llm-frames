//
//  TimelineReport.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What `timeline` prints: for every storyline clip its ranges, speed and incoming transition, and for every other
// clip its visible range, kind, lane, parent and animation. `time` is the sequence time `--at` asks it at, where every
// entry also gives what its time map gives, nil for a report asked at none.
package struct TimelineReport: Equatable, Sendable {
    // MARK: - Property
    let duration: Double
    let time: Double?
    let storyline: [TimelineStorylineEntry]
    let clips: [TimelineClipEntry]

    // MARK: - Initializer
    init(
        duration: Double,
        time: Double?,
        storyline: [TimelineStorylineEntry],
        clips: [TimelineClipEntry]
    ) {
        self.duration = duration
        self.time = time
        self.storyline = storyline
        self.clips = clips
    }

    // MARK: - Public
    // MARK: - Private
}

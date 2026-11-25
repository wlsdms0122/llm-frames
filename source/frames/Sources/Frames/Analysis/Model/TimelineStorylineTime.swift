//
//  TimelineStorylineTime.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a storyline clip's time map gives at the sequence time `timeline --at` names (FRAMES-8): its clip time, and the
// media time it shows, nil for a solid, which has no media.
struct TimelineStorylineTime: Equatable, Sendable {
    // MARK: - Property
    let clipTime: Double
    let mediaTime: Double?

    // MARK: - Initializer
    init(
        clipTime: Double,
        mediaTime: Double?
    ) {
        self.clipTime = clipTime
        self.mediaTime = mediaTime
    }

    // MARK: - Public
    // MARK: - Private
}

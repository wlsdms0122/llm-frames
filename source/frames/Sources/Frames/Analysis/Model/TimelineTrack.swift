//
//  TimelineTrack.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// Where a track on a clip follows its target (FRAMES-12): the place of the clip whose video or image sequence it
// follows, and the pinned media times of the first and the last frame of it the clip shows while it is drawn.
struct TimelineTrack: Equatable, Sendable {
    // MARK: - Property
    let clip: String
    let first: Double
    let last: Double

    // MARK: - Initializer
    init(
        clip: String,
        first: Double,
        last: Double
    ) {
        self.clip = clip
        self.first = first
        self.last = last
    }

    // MARK: - Public
    // MARK: - Private
}

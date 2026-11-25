//
//  TimelineStorylineTime.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// What a storyline clip gives at the sequence time `timeline --at` names: what its time map gives there (FRAMES-8), its
// clip time and the media time it shows, nil for a solid, which has no media, and where it lies there.
struct TimelineStorylineTime: Equatable, Sendable {
    // MARK: - Property
    let clipTime: Double
    let mediaTime: Double?
    let geometry: TimelineGeometry

    // MARK: - Initializer
    init(
        clipTime: Double,
        mediaTime: Double?,
        geometry: TimelineGeometry
    ) {
        self.clipTime = clipTime
        self.mediaTime = mediaTime
        self.geometry = geometry
    }

    // MARK: - Public
    // MARK: - Private
}

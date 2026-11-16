//
//  StorylineSource.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// What a storyline clip plays: its media (nil for a solid), its clip range `[in, out)` on its clip time, and its speed.
// A still or solid clip's clip range is `[0, duration)` at speed 1.
struct StorylineSource: Equatable, Sendable {
    // MARK: - Property
    let kind: ClipKind
    let media: MediaPlan?
    let clipRange: TimeRange
    let speed: Double

    var duration: Double {
        clipRange.length / speed
    }

    // MARK: - Initializer
    init(
        kind: ClipKind,
        media: MediaPlan?,
        clipRange: TimeRange,
        speed: Double
    ) {
        self.kind = kind
        self.media = media
        self.clipRange = clipRange
        self.speed = speed
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  TimelineStorylineEntry.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `media` is the file, or nil for a solid or a document written in place. `clip` is `[in, out)` on its clip time.
struct TimelineStorylineEntry: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let id: String?
    let media: String?
    let edit: TimeRange
    let drawn: TimeRange
    let clip: TimeRange
    let speed: Double
    let transition: TimelineTransition?
    let nested: TimelineReport?

    // MARK: - Initializer
    init(
        place: Place,
        id: String?,
        media: String?,
        edit: TimeRange,
        drawn: TimeRange,
        clip: TimeRange,
        speed: Double,
        transition: TimelineTransition?,
        nested: TimelineReport?
    ) {
        self.place = place
        self.id = id
        self.media = media
        self.edit = edit
        self.drawn = drawn
        self.clip = clip
        self.speed = speed
        self.transition = transition
        self.nested = nested
    }

    // MARK: - Public
    // MARK: - Private
}

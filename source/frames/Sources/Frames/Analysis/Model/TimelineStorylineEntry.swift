//
//  TimelineStorylineEntry.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `media` is the file as the document wrote it, or nil for a solid, a document written in place and a template
// instance. `clip` is `[in, out)` on its clip time, `sound` the range its sound plays over, its split applied, or nil
// where it plays no sound, and `isTimeRemapped` whether its media time comes from `timeRemap`, when its speed is 1.
struct TimelineStorylineEntry: Equatable, Sendable {
    // MARK: - Property
    let place: String
    let id: String?
    let media: String?
    let edit: TimeRange
    let drawn: TimeRange
    let clip: TimeRange
    let sound: TimeRange?
    let speed: Double
    let isTimeRemapped: Bool
    let transition: TimelineTransition?
    let nested: TimelineReport?

    // MARK: - Initializer
    init(
        place: String,
        id: String?,
        media: String?,
        edit: TimeRange,
        drawn: TimeRange,
        clip: TimeRange,
        sound: TimeRange?,
        speed: Double,
        isTimeRemapped: Bool,
        transition: TimelineTransition?,
        nested: TimelineReport?
    ) {
        self.place = place
        self.id = id
        self.media = media
        self.edit = edit
        self.drawn = drawn
        self.clip = clip
        self.sound = sound
        self.speed = speed
        self.isTimeRemapped = isTimeRemapped
        self.transition = transition
        self.nested = nested
    }

    // MARK: - Public
    // MARK: - Private
}

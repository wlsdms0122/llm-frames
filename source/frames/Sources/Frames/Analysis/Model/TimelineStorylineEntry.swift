//
//  TimelineStorylineEntry.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `kind` is the clip's kind, `media` the pinned absolute path of its media file, an image sequence's directory for one,
// nil for a solid and for a compound clip or a template instance, whose media `nested` gives, and `page` the page of a
// PDF it shows, nil for every other medium. `clip` is `[in, out)` on its clip time, `sound` the range its sound plays
// over, its split applied, or nil where it plays no sound, and `isTimeRemapped` whether its media time comes from
// `timeRemap`, when its speed is 1. `time` is what its time map gives at the time the report is asked at, nil for a
// report asked at none.
struct TimelineStorylineEntry: Equatable, Sendable {
    // MARK: - Property
    let place: String
    let id: String?
    let kind: String
    let media: String?
    let page: Int?
    let edit: TimeRange
    let drawn: TimeRange
    let clip: TimeRange
    let sound: TimeRange?
    let speed: Double
    let isTimeRemapped: Bool
    let transition: TimelineTransition?
    let time: TimelineStorylineTime?
    let nested: TimelineReport?

    // MARK: - Initializer
    init(
        place: String,
        id: String?,
        kind: String,
        media: String?,
        page: Int?,
        edit: TimeRange,
        drawn: TimeRange,
        clip: TimeRange,
        sound: TimeRange?,
        speed: Double,
        isTimeRemapped: Bool,
        transition: TimelineTransition?,
        time: TimelineStorylineTime?,
        nested: TimelineReport?
    ) {
        self.place = place
        self.id = id
        self.kind = kind
        self.media = media
        self.page = page
        self.edit = edit
        self.drawn = drawn
        self.clip = clip
        self.sound = sound
        self.speed = speed
        self.isTimeRemapped = isTimeRemapped
        self.transition = transition
        self.time = time
        self.nested = nested
    }

    // MARK: - Public
    // MARK: - Private
}

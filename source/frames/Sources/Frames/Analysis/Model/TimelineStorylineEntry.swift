//
//  TimelineStorylineEntry.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `kind` is the clip's kind, `media` the pinned absolute path of its media file, an image sequence's directory for one,
// nil for a solid and for a compound clip or a template instance, whose media `nested` gives, and `page` the page of a
// PDF it shows, nil for every other medium. `fps` is the rate an image sequence is read at, nil for every other
// medium, whose files give its rate, and in a resolved document, which pins its frames' times and no rate. `instant`
// is its `in` in sequence time, nil in a resolved document, which keeps no instant, `clock` the map of the times it
// writes to sequence time, `space` where its `position` and `cornerPin` are written, output pixels, and `ownSpace`
// where its `crop` and `mask` are. `tracked` is where a track on it follows its target, nil where it has no video or
// image sequence of its own and in a resolved document, which holds every track as resolve fitted it. `clip` is `[in, out)` on its clip time, `sound` the range its sound plays
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
    let fps: Double?
    let instant: Double?
    let clock: TimelineClock
    let space: CoordinateSpace
    let ownSpace: CoordinateSpace
    let tracked: TimelineTrack?
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
        fps: Double?,
        instant: Double?,
        clock: TimelineClock,
        space: CoordinateSpace,
        ownSpace: CoordinateSpace,
        tracked: TimelineTrack?,
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
        self.fps = fps
        self.instant = instant
        self.clock = clock
        self.space = space
        self.ownSpace = ownSpace
        self.tracked = tracked
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

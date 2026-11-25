//
//  TimelineClipEntry.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// `media` is the pinned absolute path of a media clip's file, an image sequence's directory for one, nil for every
// other clip and for a compound clip or a template instance, whose media `nested` gives, and `page` the page of a PDF
// it shows, nil for every other clip. `fps` is the rate an image sequence is read at, nil for every other medium, whose
// files give its rate, and in a resolved document, which pins its frames' times and no rate. `instant` is where the
// values it writes without keyframes take effect, in sequence time, nil in a resolved document, which keeps no instant,
// and `clock` the map of the times it writes to sequence time. `space` is where its `position`, `area`, `points` and
// `cornerPin` are written, and `ownSpace` where its `crop` and `mask` are. `sound` is the range a visual media clip's
// sound plays over, its split applied, nil for every other clip and for one that plays no sound. `lane` is nil for a
// sound, `storyline` is the place of the storyline clip a connected clip belongs to, and `parent` is the place of the
// clip whose space a parented clip is placed in. `time` is what its time map gives at the time the report is asked at,
// nil for a report asked at none.
struct TimelineClipEntry: Equatable, Sendable {
    // MARK: - Property
    let place: String
    let id: String?
    let kind: String
    let media: String?
    let page: Int?
    let fps: Double?
    let instant: Double?
    let clock: TimelineClock
    let space: CoordinateSpace?
    let ownSpace: CoordinateSpace?
    let visible: TimeRange
    let sound: TimeRange?
    let lane: Int?
    let storyline: String?
    let parent: String?
    let animation: TimelineAnimation?
    let time: TimelineClipTime?
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
        space: CoordinateSpace?,
        ownSpace: CoordinateSpace?,
        visible: TimeRange,
        sound: TimeRange?,
        lane: Int?,
        storyline: String?,
        parent: String?,
        animation: TimelineAnimation?,
        time: TimelineClipTime?,
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
        self.visible = visible
        self.sound = sound
        self.lane = lane
        self.storyline = storyline
        self.parent = parent
        self.animation = animation
        self.time = time
        self.nested = nested
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  ClipPlan.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A connected or sequence clip on the sequence clock. `space` is its own coordinate space, which its mask is in and
// which it gives its children. `window` is where its `at` puts it, and `visible` is the part of the window it is seen
// or heard in. `storyline` is the index of the storyline clip a connected clip belongs to, and `clock` maps its
// instants to sequence time. `instant`, the start of its window, is where its areas take effect. `keyframes` are in
// sequence time.
struct ClipPlan: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let id: String?
    let kind: ClipKind
    let space: OwnSpace
    let storyline: Int?
    let parent: ClipParent?
    let trackMatte: TrackMatte?
    let lane: Int?
    let clock: TimeMap
    let window: TimeRange
    let visible: TimeRange
    let instant: Double
    let animation: AnimationPlan
    let media: MediaPlan?
    let timing: MediaTiming?
    let keyframes: [KeyframeInstant]

    // The media time a timed media clip shows, nil for a still, a title, a shape or an adjustment.
    var mediaClock: MediaClock? {
        timing.map { timing in MediaClock(timing: timing, frames: media?.frames) }
    }

    // MARK: - Initializer
    init(
        place: Place,
        id: String?,
        kind: ClipKind,
        space: OwnSpace,
        storyline: Int?,
        parent: ClipParent? = nil,
        trackMatte: TrackMatte?,
        lane: Int?,
        clock: TimeMap,
        window: TimeRange,
        visible: TimeRange,
        instant: Double,
        animation: AnimationPlan,
        media: MediaPlan?,
        timing: MediaTiming?,
        keyframes: [KeyframeInstant]
    ) {
        self.place = place
        self.id = id
        self.kind = kind
        self.space = space
        self.storyline = storyline
        self.parent = parent
        self.trackMatte = trackMatte
        self.lane = lane
        self.clock = clock
        self.window = window
        self.visible = visible
        self.instant = instant
        self.animation = animation
        self.media = media
        self.timing = timing
        self.keyframes = keyframes
    }

    // MARK: - Public
    func narrowed(to visible: TimeRange) -> ClipPlan {
        ClipPlan(
            place: place,
            id: id,
            kind: kind,
            space: space,
            storyline: storyline,
            parent: parent,
            trackMatte: trackMatte,
            lane: lane,
            clock: clock,
            window: window,
            visible: visible,
            instant: instant,
            animation: animation,
            media: media,
            timing: timing,
            keyframes: keyframes
        )
    }

    func parented(by parent: ClipParent?) -> ClipPlan {
        ClipPlan(
            place: place,
            id: id,
            kind: kind,
            space: space,
            storyline: storyline,
            parent: parent,
            trackMatte: trackMatte,
            lane: lane,
            clock: clock,
            window: window,
            visible: visible,
            instant: instant,
            animation: animation,
            media: media,
            timing: timing,
            keyframes: keyframes
        )
    }

    // MARK: - Private
}

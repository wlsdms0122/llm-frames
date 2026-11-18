//
//  StorylinePlan.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A storyline clip on the sequence clock. Its edit range lies between its edit points, and its drawn range runs from
// the start of its incoming transition to the end of its outgoing one. `trackMatte` is its track matte, and
// `keyframes` and `timeRemap` are in sequence time, `timeRemap` nil for a clip that writes none.
struct StorylinePlan: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let id: String?
    let source: StorylineSource
    let edit: TimeRange
    let drawn: TimeRange
    let transition: TransitionPlan?
    let trackMatte: TrackMatte?
    let keyframes: [KeyframeInstant]
    let timeRemap: [Keyframe<Double>]?

    var map: TimeMap {
        TimeMap(origin: edit.start, in: source.clipRange.start, speed: source.speed)
    }

    // The media time it shows, nil for a solid. In a handle where the media runs out, its first or last frame holds,
    // and a still simply goes on.
    var clock: MediaClock? {
        guard let media = source.media else { return nil }

        return MediaClock(line: map, timeRemap: timeRemap, frames: media.frames)
    }

    // Where a static crop takes effect: the clip's `in`.
    var instant: Double {
        edit.start
    }

    // MARK: - Initializer
    init(
        place: Place,
        id: String?,
        source: StorylineSource,
        edit: TimeRange,
        drawn: TimeRange,
        transition: TransitionPlan?,
        trackMatte: TrackMatte?,
        keyframes: [KeyframeInstant],
        timeRemap: [Keyframe<Double>]?
    ) {
        self.place = place
        self.id = id
        self.source = source
        self.edit = edit
        self.drawn = drawn
        self.transition = transition
        self.trackMatte = trackMatte
        self.keyframes = keyframes
        self.timeRemap = timeRemap
    }

    // MARK: - Public
    // The media time it shows at a sequence time, or a solid's clip time.
    func mediaTime(atSequenceTime time: Double) -> Double {
        clock?.mediaTime(atSequenceTime: time) ?? map.clipTime(atSequenceTime: time)
    }

    // MARK: - Private
}

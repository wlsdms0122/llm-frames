//
//  StorylinePlan.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A storyline clip on the sequence clock. Its edit range lies between its edit points, and its drawn range runs from
// the start of its incoming transition to the end of its outgoing one. `keyframes` are in sequence time.
struct StorylinePlan: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let id: String?
    let source: StorylineSource
    let edit: TimeRange
    let drawn: TimeRange
    let transition: TransitionPlan?
    let keyframes: [KeyframeInstant]

    var map: TimeMap {
        TimeMap(origin: edit.start, in: source.clipRange.start, speed: source.speed)
    }

    // MARK: - Initializer
    init(
        place: Place,
        id: String?,
        source: StorylineSource,
        edit: TimeRange,
        drawn: TimeRange,
        transition: TransitionPlan?,
        keyframes: [KeyframeInstant]
    ) {
        self.place = place
        self.id = id
        self.source = source
        self.edit = edit
        self.drawn = drawn
        self.transition = transition
        self.keyframes = keyframes
    }

    // MARK: - Public
    // In a handle where the media runs out, its first or last frame holds. A still or solid simply goes on.
    func mediaTime(atSequenceTime time: Double) -> Double {
        let clipTime = map.clipTime(atSequenceTime: time)
        guard let media = source.media else { return clipTime }

        return media.clamped(clipTime)
    }

    // MARK: - Private
}

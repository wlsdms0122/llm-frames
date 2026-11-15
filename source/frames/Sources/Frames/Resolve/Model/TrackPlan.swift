//
//  TrackPlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What tracking decided for a sequence: the time plan with each tracked connected clip's visible window narrowed to
// the frames followed, and what the tracker followed for each storyline clip and each other clip, in the time plan's
// order, nil where nothing is tracked.
struct TrackPlan: Equatable, Sendable {
    // MARK: - Property
    let time: TimePlan
    let storyline: [Track?]
    let clips: [Track?]

    // MARK: - Initializer
    init(
        time: TimePlan,
        storyline: [Track?],
        clips: [Track?]
    ) {
        self.time = time
        self.storyline = storyline
        self.clips = clips
    }

    // MARK: - Public
    // MARK: - Private
}

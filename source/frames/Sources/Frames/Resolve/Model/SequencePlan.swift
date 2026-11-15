//
//  SequencePlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve decided for a sequence before evaluation: its time plan, with every visible window narrowed by its
// track, its format, and what was found and set for each storyline clip and each other clip, in the time plan's order.
struct SequencePlan: Equatable, Sendable {
    // MARK: - Property
    let time: TimePlan
    let format: FormatPlan
    let storyline: [StorylineGeometry]
    let clips: [ClipGeometry]

    // MARK: - Initializer
    init(
        time: TimePlan,
        format: FormatPlan,
        storyline: [StorylineGeometry],
        clips: [ClipGeometry]
    ) {
        self.time = time
        self.format = format
        self.storyline = storyline
        self.clips = clips
    }

    // MARK: - Public
    // MARK: - Private
}

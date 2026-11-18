//
//  SequencePlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve decided for a sequence before evaluation. `time` has every visible window narrowed by its track,
// `storyline` and `clips` are in the time plan's order, and `sound` is in document order.
struct SequencePlan: Equatable, Sendable {
    // MARK: - Property
    let time: TimePlan
    let format: FormatPlan
    let storyline: [StorylineGeometry]
    let clips: [ClipGeometry]
    let sound: [SoundPlan]

    // MARK: - Initializer
    init(
        time: TimePlan,
        format: FormatPlan,
        storyline: [StorylineGeometry],
        clips: [ClipGeometry],
        sound: [SoundPlan]
    ) {
        self.time = time
        self.format = format
        self.storyline = storyline
        self.clips = clips
        self.sound = sound
    }

    // MARK: - Public
    // MARK: - Private
}

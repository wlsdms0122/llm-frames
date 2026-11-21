//
//  SequencePlan.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve decided for a sequence before evaluation. `time` has every visible window narrowed by its track,
// `storyline` and `clips` are in the time plan's order, `sound` is in document order, and `audioFilter` is the
// sequence's own audio filter, its bus's chain, as a timed list of entries `{ops, mix}` in its sequence time, `off`
// for none.
struct SequencePlan: Equatable, Sendable {
    // MARK: - Property
    let time: TimePlan
    let format: FormatPlan
    let storyline: [StorylineGeometry]
    let clips: [ClipGeometry]
    let sound: [SoundPlan]
    let audioFilter: TimedValue

    // MARK: - Initializer
    init(
        time: TimePlan,
        format: FormatPlan,
        storyline: [StorylineGeometry],
        clips: [ClipGeometry],
        sound: [SoundPlan],
        audioFilter: TimedValue
    ) {
        self.time = time
        self.format = format
        self.storyline = storyline
        self.clips = clips
        self.sound = sound
        self.audioFilter = audioFilter
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  TimePlan.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The time plan of a sequence. `clips` are in document order: each storyline clip's connected clips, then the
// sequence clips. `sequence` is the document it was planned from and `theme` the theme merged for it, which the rest of
// resolve reads on, with the `defaults` it gives.
struct TimePlan: Equatable, Sendable {
    // MARK: - Property
    let duration: Double
    let fps: Double
    let storyline: [StorylinePlan]
    let clips: [ClipPlan]
    let sequence: SequenceDocument
    let theme: MergedTheme
    let defaults: ThemeDefaults

    // MARK: - Initializer
    init(
        duration: Double,
        fps: Double,
        storyline: [StorylinePlan],
        clips: [ClipPlan],
        sequence: SequenceDocument,
        theme: MergedTheme,
        defaults: ThemeDefaults
    ) {
        self.duration = duration
        self.fps = fps
        self.storyline = storyline
        self.clips = clips
        self.sequence = sequence
        self.theme = theme
        self.defaults = defaults
    }

    // MARK: - Public
    // The storyline clip whose edit range holds the time, so at an edit point it is the one that starts there.
    func storylineIndex(at time: Double) -> Int? {
        storyline.firstIndex { $0.edit.contains(time) }
    }

    // The same plan with clips whose visible windows resolve narrowed further.
    func replacingClips(_ clips: [ClipPlan]) -> TimePlan {
        TimePlan(
            duration: duration,
            fps: fps,
            storyline: storyline,
            clips: clips,
            sequence: sequence,
            theme: theme,
            defaults: defaults
        )
    }

    // MARK: - Private
}

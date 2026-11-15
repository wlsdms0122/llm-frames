//
//  TimePlan.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// The time plan of a sequence. `clips` are in document order: each storyline clip's connected clips, then the
// sequence clips.
struct TimePlan: Equatable, Sendable {
    // MARK: - Property
    let duration: Double
    let fps: Double
    let storyline: [StorylinePlan]
    let clips: [ClipPlan]

    // MARK: - Initializer
    init(
        duration: Double,
        fps: Double,
        storyline: [StorylinePlan],
        clips: [ClipPlan]
    ) {
        self.duration = duration
        self.fps = fps
        self.storyline = storyline
        self.clips = clips
    }

    // MARK: - Public
    // The storyline clip whose edit range holds the time, so at an edit point it is the one that starts there.
    func storylineIndex(at time: Double) -> Int? {
        storyline.firstIndex { $0.edit.contains(time) }
    }

    // MARK: - Private
}

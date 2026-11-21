//
//  SequenceDocument.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A checked sequence document, as far as the time plan reads it. `place` is where the document stands, so a
// compound clip's places continue the place of the clip that holds it. `audioFilter` is its bus's chain as written,
// its keyframes on sequence time, and `keyframes` the sequence's own keyframes with the leaves each writes.
struct SequenceDocument: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let theme: ThemeReference?
    let format: SequenceFormat
    let storyline: [StorylineClip]
    let clips: [Clip]
    let audioFilter: LookProperty?
    let keyframes: [KeyframeInstant]

    // MARK: - Initializer
    init(
        place: Place,
        theme: ThemeReference?,
        format: SequenceFormat,
        storyline: [StorylineClip],
        clips: [Clip],
        audioFilter: LookProperty?,
        keyframes: [KeyframeInstant]
    ) {
        self.place = place
        self.theme = theme
        self.format = format
        self.storyline = storyline
        self.clips = clips
        self.audioFilter = audioFilter
        self.keyframes = keyframes
    }

    // MARK: - Public
    // MARK: - Private
}

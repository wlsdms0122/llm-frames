//
//  SequenceDocument.swift
//  Frames
//
//  Created by JSilver on 11/15/26.
//

// A checked sequence document, as far as the time plan reads it. `place` is where the document stands, so a
// compound clip's places continue the place of the clip that holds it.
struct SequenceDocument: Equatable, Sendable {
    // MARK: - Property
    let place: Place
    let theme: ThemeReference?
    let format: SequenceFormat
    let storyline: [StorylineClip]
    let clips: [Clip]

    // MARK: - Initializer
    init(
        place: Place,
        theme: ThemeReference?,
        format: SequenceFormat,
        storyline: [StorylineClip],
        clips: [Clip]
    ) {
        self.place = place
        self.theme = theme
        self.format = format
        self.storyline = storyline
        self.clips = clips
    }

    // MARK: - Public
    // MARK: - Private
}

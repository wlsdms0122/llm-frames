//
//  StorylineGeometry.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve found for a storyline clip's picture: its crop as written, found in its media with keyframes in
// sequence time (nil for the whole picture), what its track followed, the plan of a nested sequence it shows, the
// filter operations it applies, their lengths already scaled, a solid's colour, and how its picture is drawn.
struct StorylineGeometry: Equatable, Sendable {
    // MARK: - Property
    let crop: PropertyValue<FoundArea>?
    let track: Track?
    let nested: SequencePlan?
    let filter: [FilterOperation]
    let color: Color?
    let appearance: StorylineAppearance

    // MARK: - Initializer
    init(
        crop: PropertyValue<FoundArea>?,
        track: Track?,
        nested: SequencePlan?,
        filter: [FilterOperation] = [],
        color: Color? = nil,
        appearance: StorylineAppearance
    ) {
        self.crop = crop
        self.track = track
        self.nested = nested
        self.filter = filter
        self.color = color
        self.appearance = appearance
    }

    // MARK: - Public
    // MARK: - Private
}

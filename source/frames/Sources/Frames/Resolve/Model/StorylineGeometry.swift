//
//  StorylineGeometry.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve found for a storyline clip's picture: its crop as written, found in its media with keyframes in
// sequence time (nil for the whole picture), what its track followed, the plan of a nested sequence it shows, the
// filter operations it applies, their lengths already scaled, and a solid's colour.
struct StorylineGeometry: Equatable, Sendable {
    // MARK: - Property
    let crop: PropertyValue<FoundArea>?
    let track: Track?
    let nested: SequencePlan?
    let filter: [FilterOperation]
    let color: Color?

    // MARK: - Initializer
    init(
        crop: PropertyValue<FoundArea>?,
        track: Track?,
        nested: SequencePlan?,
        filter: [FilterOperation] = [],
        color: Color? = nil
    ) {
        self.crop = crop
        self.track = track
        self.nested = nested
        self.filter = filter
        self.color = color
    }

    // MARK: - Public
    // MARK: - Private
}

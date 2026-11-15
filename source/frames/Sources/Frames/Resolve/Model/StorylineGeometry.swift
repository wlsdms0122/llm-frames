//
//  StorylineGeometry.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve found for a storyline clip's picture: its crop as written, found in its media with keyframes in
// sequence time (nil for the whole picture), what its track followed, and the plan of a nested document it shows.
struct StorylineGeometry: Equatable, Sendable {
    // MARK: - Property
    let crop: PropertyValue<FoundArea>?
    let track: Track?
    let nested: SequencePlan?

    // MARK: - Initializer
    init(
        crop: PropertyValue<FoundArea>?,
        track: Track?,
        nested: SequencePlan?
    ) {
        self.crop = crop
        self.track = track
        self.nested = nested
    }

    // MARK: - Public
    // MARK: - Private
}

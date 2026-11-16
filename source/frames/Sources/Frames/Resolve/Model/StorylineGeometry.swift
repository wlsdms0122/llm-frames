//
//  StorylineGeometry.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve found for a storyline clip's picture: its crop as written, found in its media with keyframes in
// sequence time (nil for the whole picture), what its track followed, the plan of a nested document it shows, and the filter operations it
// applies, their lengths already scaled.
struct StorylineGeometry: Equatable, Sendable {
    // MARK: - Property
    let crop: PropertyValue<FoundArea>?
    let track: Track?
    let nested: DocumentPlan?
    let filter: [FilterOperation]

    // MARK: - Initializer
    init(
        crop: PropertyValue<FoundArea>?,
        track: Track?,
        nested: DocumentPlan?,
        filter: [FilterOperation] = []
    ) {
        self.crop = crop
        self.track = track
        self.nested = nested
        self.filter = filter
    }

    // MARK: - Public
    // MARK: - Private
}

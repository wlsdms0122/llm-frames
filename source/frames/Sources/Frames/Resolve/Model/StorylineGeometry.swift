//
//  StorylineGeometry.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve found for a storyline clip's picture, with keyframes in sequence time. `crop` and `mask` are found in
// its media, nil for the whole picture and for no mask. The lengths in `filter` are already scaled, and `color` is a
// solid's.
struct StorylineGeometry: Equatable, Sendable {
    // MARK: - Property
    let crop: PropertyValue<FoundArea>?
    let mask: PropertyValue<[ResolvedMask]>?
    let track: Track?
    let nested: SequencePlan?
    let filter: [FilterOperation]
    let color: Color?
    let appearance: StorylineAppearance

    // MARK: - Initializer
    init(
        crop: PropertyValue<FoundArea>?,
        mask: PropertyValue<[ResolvedMask]>?,
        track: Track?,
        nested: SequencePlan?,
        filter: [FilterOperation] = [],
        color: Color? = nil,
        appearance: StorylineAppearance
    ) {
        self.crop = crop
        self.mask = mask
        self.track = track
        self.nested = nested
        self.filter = filter
        self.color = color
        self.appearance = appearance
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  StorylineGeometry.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve found for a storyline clip's picture, with keyframes in sequence time. `crop` and `mask` are found in
// its media, nil for the whole picture and for no mask. `filter` is timed, `off` for none, its lengths in output
// pixels, and `color` is a solid's. `isCropOnTrackFrame` says a tracked clip's crop is written without keyframes and
// true on the track's frame.
struct StorylineGeometry: Equatable, Sendable {
    // MARK: - Property
    let crop: PropertyValue<FoundArea>?
    let mask: [ResolvedMask]?
    let track: Track?
    let isCropOnTrackFrame: Bool
    let nested: SequencePlan?
    let filter: TimedValue
    let color: Color?
    let appearance: StorylineAppearance

    // MARK: - Initializer
    init(
        crop: PropertyValue<FoundArea>?,
        mask: [ResolvedMask]?,
        track: Track?,
        isCropOnTrackFrame: Bool = false,
        nested: SequencePlan?,
        filter: TimedValue = .off,
        color: Color? = nil,
        appearance: StorylineAppearance
    ) {
        self.crop = crop
        self.mask = mask
        self.track = track
        self.isCropOnTrackFrame = isCropOnTrackFrame
        self.nested = nested
        self.filter = filter
        self.color = color
        self.appearance = appearance
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  StorylineGeometry.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve found for a storyline clip's picture, with keyframes in sequence time. `content` is what it shows. `crop`
// and `mask` are found in its media, nil for the whole picture and for no mask. `filter` is timed, `off` for none, its
// lengths in output pixels. `isCropOnTrackFrame` says a tracked clip's crop is written without keyframes and true on
// the track's frame.
struct StorylineGeometry: Equatable, Sendable {
    // MARK: - Property
    let crop: PropertyValue<Rectangle>?
    let mask: [ResolvedMask]?
    let track: Track?
    let isCropOnTrackFrame: Bool
    let filter: TimedValue
    let content: StorylineContent
    let appearance: StorylineAppearance

    // The plan of the nested sequence it shows, nil for a solid and a media file.
    var nested: SequencePlan? {
        guard case let .nested(nested) = content else { return nil }

        return nested
    }

    // MARK: - Initializer
    init(
        crop: PropertyValue<Rectangle>?,
        mask: [ResolvedMask]?,
        track: Track?,
        isCropOnTrackFrame: Bool = false,
        filter: TimedValue = .off,
        content: StorylineContent,
        appearance: StorylineAppearance
    ) {
        self.crop = crop
        self.mask = mask
        self.track = track
        self.isCropOnTrackFrame = isCropOnTrackFrame
        self.filter = filter
        self.content = content
        self.appearance = appearance
    }

    // MARK: - Public
    // MARK: - Private
}

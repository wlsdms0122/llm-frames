//
//  ClipGeometry.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve found and set for a connected or sequence clip, with keyframes in sequence time. `area`, a path's
// `points` and `position` are in the space a parented clip's parent gives, and an unparented clip's in output pixels.
// `crop` is in the clip's own media, `mask` in the clip's own coordinate space, and `track` is what a tracked clip
// follows. `box` is where a title, a media clip or a shape given by `width` and `height` is drawn, and `position` the
// anchor point it was found from. `title` is the text set for a title, `nested` the plan of a nested sequence the clip
// shows, and `appearance` how it is drawn.
struct ClipGeometry: Equatable, Sendable {
    // MARK: - Property
    let area: PropertyValue<FoundArea>?
    let points: PropertyValue<[Point]>?
    let position: PropertyValue<Point>?
    let box: ClipBox?
    let crop: PropertyValue<FoundArea>?
    let mask: PropertyValue<[ResolvedMask]>?
    let track: StorylineTrack?
    let title: TextLayout?
    let nested: SequencePlan?
    let appearance: ClipAppearance

    // MARK: - Initializer
    init(
        area: PropertyValue<FoundArea>?,
        points: PropertyValue<[Point]>? = nil,
        position: PropertyValue<Point>?,
        box: ClipBox?,
        crop: PropertyValue<FoundArea>?,
        mask: PropertyValue<[ResolvedMask]>?,
        track: StorylineTrack?,
        title: TextLayout?,
        nested: SequencePlan?,
        appearance: ClipAppearance
    ) {
        self.area = area
        self.points = points
        self.position = position
        self.box = box
        self.crop = crop
        self.mask = mask
        self.track = track
        self.title = title
        self.nested = nested
        self.appearance = appearance
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  ClipGeometry.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve found and set for a connected or sequence clip, with keyframes in sequence time. `area` and `position`
// are in the media pixels of the picture a parented clip is on, and a sequence clip's area in output pixels. `crop` is
// in the clip's own media. `title` and `label` are the text set for a title and a shape's label, and `nested` the
// plan of a nested document the clip shows.
struct ClipGeometry: Equatable, Sendable {
    // MARK: - Property
    let area: PropertyValue<FoundArea>?
    let position: PropertyValue<Point>?
    let crop: PropertyValue<FoundArea>?
    let track: Track?
    let title: TextLayout?
    let label: LabelPlan?
    let nested: SequencePlan?

    // MARK: - Initializer
    init(
        area: PropertyValue<FoundArea>?,
        position: PropertyValue<Point>?,
        crop: PropertyValue<FoundArea>?,
        track: Track?,
        title: TextLayout?,
        label: LabelPlan?,
        nested: SequencePlan?
    ) {
        self.area = area
        self.position = position
        self.crop = crop
        self.track = track
        self.title = title
        self.label = label
        self.nested = nested
    }

    // MARK: - Public
    // MARK: - Private
}

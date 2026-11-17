//
//  ClipGeometry.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What resolve found and set for a connected or sequence clip, with keyframes in sequence time. `area` and `position`
// are in the media pixels of the picture a parented clip is on, and a sequence clip's area in output pixels. `crop` is
// in the clip's own media. `box` is where a title or media clip is drawn, and `position` the anchor point it was found
// from. `title` is the text set for a title, `nested` the plan of a nested sequence the clip shows, and `appearance`
// how it is drawn.
struct ClipGeometry: Equatable, Sendable {
    // MARK: - Property
    let area: PropertyValue<FoundArea>?
    let position: PropertyValue<Point>?
    let box: ClipBox?
    let crop: PropertyValue<FoundArea>?
    let track: Track?
    let title: TextLayout?
    let nested: SequencePlan?
    let appearance: ClipAppearance

    // MARK: - Initializer
    init(
        area: PropertyValue<FoundArea>?,
        position: PropertyValue<Point>?,
        box: ClipBox?,
        crop: PropertyValue<FoundArea>?,
        track: Track?,
        title: TextLayout?,
        nested: SequencePlan?,
        appearance: ClipAppearance
    ) {
        self.area = area
        self.position = position
        self.box = box
        self.crop = crop
        self.track = track
        self.title = title
        self.nested = nested
        self.appearance = appearance
    }

    // MARK: - Public
    // MARK: - Private
}

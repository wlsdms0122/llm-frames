//
//  FoundGeometry.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// What resolve finds of a connected or sequence clip's geometry before tracks and parents' spaces are planned, every
// text form searched. `area`, a path's `points` and `position` are in the space the clip's parent gives, `crop` in its
// own media and `mask` in its own coordinate space. `isInOutputPixels` says whether the clip's coordinates are output
// pixels, which under content fit are the measuring space, so the clip moves with the content.
struct FoundGeometry: Equatable, Sendable {
    // MARK: - Property
    let area: PropertyValue<FoundArea>?
    let points: PropertyValue<[Point]>?
    let position: PropertyValue<Point>?
    let crop: PropertyValue<FoundArea>?
    let mask: PropertyValue<[ResolvedMask]>?
    let isInOutputPixels: Bool

    // MARK: - Initializer
    init(
        area: PropertyValue<FoundArea>?,
        points: PropertyValue<[Point]>?,
        position: PropertyValue<Point>?,
        crop: PropertyValue<FoundArea>?,
        mask: PropertyValue<[ResolvedMask]>?,
        isInOutputPixels: Bool
    ) {
        self.area = area
        self.points = points
        self.position = position
        self.crop = crop
        self.mask = mask
        self.isInOutputPixels = isInOutputPixels
    }

    // MARK: - Public
    // MARK: - Private
}

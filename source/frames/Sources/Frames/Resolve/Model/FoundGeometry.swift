//
//  FoundGeometry.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// What resolve finds of a connected or sequence clip's geometry before tracks and parents' spaces are planned, every
// text form searched. `area`, a path's `points` and `position` are in the space the clip's parent gives, `crop` in its
// own media and `mask` in the space its geometry is searched in. Under content fit output pixels are the measuring
// space, so a clip with `isInOutputPixels` moves with the content.
struct FoundGeometry: Equatable, Sendable {
    // MARK: - Property
    let area: PropertyValue<FoundArea>?
    let points: PropertyValue<[Point]>?
    let position: PropertyValue<Point>?
    let crop: PropertyValue<FoundArea>?
    let mask: [FoundMask]?
    let isInOutputPixels: Bool

    // MARK: - Initializer
    init(
        area: PropertyValue<FoundArea>?,
        points: PropertyValue<[Point]>?,
        position: PropertyValue<Point>?,
        crop: PropertyValue<FoundArea>?,
        mask: [FoundMask]?,
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

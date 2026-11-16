//
//  PictureItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A region of a picture scaled into a rectangle, filtered, then masked by its matte. `rectangle` is the region of the
// source, in its media pixels or in a nested list's output pixels, or nil for the whole source, `destination` the
// rectangle it fills, and `filter` is applied at the destination's size. `radius` rounds the destination's corners,
// and `border` and `shadow` are drawn when the picture has them.
struct PictureItem: Equatable, Sendable {
    // MARK: - Property
    let source: PictureItemSource
    let rectangle: Rectangle?
    let destination: Rectangle
    let filter: [ResolvedFilterOperation]
    let matte: PictureMatte?
    let radius: Double
    let border: MediaBorder?
    let shadow: MediaShadow?

    // MARK: - Initializer
    init(
        source: PictureItemSource,
        rectangle: Rectangle?,
        destination: Rectangle,
        filter: [ResolvedFilterOperation] = [],
        matte: PictureMatte? = nil,
        radius: Double = 0,
        border: MediaBorder? = nil,
        shadow: MediaShadow? = nil
    ) {
        self.source = source
        self.rectangle = rectangle
        self.destination = destination
        self.filter = filter
        self.matte = matte
        self.radius = radius
        self.border = border
        self.shadow = shadow
    }

    // MARK: - Public
    // MARK: - Private
}

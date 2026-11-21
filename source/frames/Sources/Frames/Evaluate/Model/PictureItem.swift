//
//  PictureItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A region of a picture scaled into a rectangle, filtered, masked by its matte, then carried onto its corner pin.
// `rectangle` is the region of the source, in its media pixels or in a nested list's output pixels, or nil for the
// whole source, and `filter` is applied at the destination's size. `cornerPin` is nil, or the strictly convex quad the
// destination's corners go to in the item's own coordinates, by the homography from the destination to it; only a
// clip's group carries one, and it shows its whole nested list, the part outside `rectangle` included (FRAMES-20).
package struct PictureItem: Equatable, Sendable {
    // MARK: - Property
    package let source: PictureItemSource
    package let rectangle: Rectangle?
    package let destination: Rectangle
    package let filter: [FilterEntry]
    package let matte: PictureMatte?
    package let radius: Double
    package let border: MediaBorder?
    package let shadow: DropShadow?
    package let cornerPin: Quad?

    // MARK: - Initializer
    package init(
        source: PictureItemSource,
        rectangle: Rectangle?,
        destination: Rectangle,
        filter: [FilterEntry] = [],
        matte: PictureMatte? = nil,
        radius: Double = 0,
        border: MediaBorder? = nil,
        shadow: DropShadow? = nil,
        cornerPin: Quad? = nil
    ) {
        self.source = source
        self.rectangle = rectangle
        self.destination = destination
        self.filter = filter
        self.matte = matte
        self.radius = radius
        self.border = border
        self.shadow = shadow
        self.cornerPin = cornerPin
    }

    // MARK: - Public
    // MARK: - Private
}

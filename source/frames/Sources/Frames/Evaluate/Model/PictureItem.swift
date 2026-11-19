//
//  PictureItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// A region of a picture scaled into a rectangle, filtered, then masked by its matte. `rectangle` is the region of the
// source, in its media pixels or in a nested list's output pixels, or nil for the whole source, and `filter` is
// applied at the destination's size.
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

    // MARK: - Initializer
    package init(
        source: PictureItemSource,
        rectangle: Rectangle?,
        destination: Rectangle,
        filter: [FilterEntry] = [],
        matte: PictureMatte? = nil,
        radius: Double = 0,
        border: MediaBorder? = nil,
        shadow: DropShadow? = nil
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

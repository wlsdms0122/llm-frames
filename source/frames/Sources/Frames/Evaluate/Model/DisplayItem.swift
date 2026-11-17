//
//  DisplayItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One drawing step of a display list. `transform` carries the item's own coordinates into output pixels, `blend` is
// its blend mode by name, `mask` a rectangle in output pixels it is cut to, and `reveal` a rectangle in its own
// coordinates, before the transform, outside which nothing of it shows, so a wipe turns with the item. `origin` is the
// clip or op that drew it, nil for the background outside the content rect and a transition cover, which no clip
// draws. A role draws without it.
package struct DisplayItem: Equatable, Sendable {
    // MARK: - Property
    package let transform: AffineTransform
    package let opacity: Double
    package let blend: String
    package let mask: Rectangle?
    package let reveal: Rectangle?
    package let content: DisplayContent
    package let origin: ItemOrigin?

    // MARK: - Initializer
    package init(
        transform: AffineTransform = .identity,
        opacity: Double = 1,
        blend: String = "normal",
        mask: Rectangle? = nil,
        reveal: Rectangle? = nil,
        content: DisplayContent,
        origin: ItemOrigin? = nil
    ) {
        self.transform = transform
        self.opacity = opacity
        self.blend = blend
        self.mask = mask
        self.reveal = reveal
        self.content = content
        self.origin = origin
    }

    // MARK: - Public
    // The same item, drawn by `origin`.
    func drawn(by origin: ItemOrigin) -> DisplayItem {
        DisplayItem(
            transform: transform,
            opacity: opacity,
            blend: blend,
            mask: mask,
            reveal: reveal,
            content: content,
            origin: origin
        )
    }

    // MARK: - Private
}

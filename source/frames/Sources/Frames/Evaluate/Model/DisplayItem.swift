//
//  DisplayItem.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// One drawing step of a display list. `transform` carries the item's own coordinates into output pixels, `blend` is
// its blend mode by name, `mask` the masks its alpha is multiplied by after its transform, combined in list order and
// empty where it has none, `trackMatte` the matte its alpha is multiplied by after its masks, nil for none, and
// `reveal` a rectangle in its own coordinates, before the transform, outside which nothing of it shows, so a wipe
// turns with the item. `origin` is the clip that drew it, nil for a transition cover, which no
// clip draws. A role draws without it.
package struct DisplayItem: Equatable, Sendable {
    // MARK: - Property
    package let transform: AffineTransform
    package let opacity: Double
    package let blend: String
    package let mask: [ItemMask]
    package let trackMatte: ItemTrackMatte?
    package let reveal: Rectangle?
    package let content: DisplayContent
    package let origin: ItemOrigin?

    // MARK: - Initializer
    package init(
        transform: AffineTransform = .identity,
        opacity: Double = 1,
        blend: String = "normal",
        mask: [ItemMask] = [],
        trackMatte: ItemTrackMatte? = nil,
        reveal: Rectangle? = nil,
        content: DisplayContent,
        origin: ItemOrigin? = nil
    ) {
        self.transform = transform
        self.opacity = opacity
        self.blend = blend
        self.mask = mask
        self.trackMatte = trackMatte
        self.reveal = reveal
        self.content = content
        self.origin = origin
    }

    // MARK: - Public
    // The same item, drawn by `origin`.
    func drawn(by origin: ItemOrigin) -> DisplayItem {
        replacing(origin: origin)
    }

    // The same item, its alpha multiplied by `mask` and then by `trackMatte`.
    func cut(
        by mask: [ItemMask],
        trackMatte: ItemTrackMatte?
    ) -> DisplayItem {
        replacing(mask: mask, trackMatte: trackMatte)
    }

    // The same item drawn as part of a track matte's source, which takes a matte clip's picture without its blend.
    func normallyBlended() -> DisplayItem {
        replacing(blend: "normal")
    }

    // MARK: - Private
    private func replacing(
        blend: String? = nil,
        mask: [ItemMask]? = nil,
        trackMatte: ItemTrackMatte?? = nil,
        origin: ItemOrigin? = nil
    ) -> DisplayItem {
        DisplayItem(
            transform: transform,
            opacity: opacity,
            blend: blend ?? self.blend,
            mask: mask ?? self.mask,
            trackMatte: trackMatte ?? self.trackMatte,
            reveal: reveal,
            content: content,
            origin: origin ?? self.origin
        )
    }
}

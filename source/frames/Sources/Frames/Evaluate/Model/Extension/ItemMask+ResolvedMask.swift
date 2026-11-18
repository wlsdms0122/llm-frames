//
//  ItemMask+ResolvedMask.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A clip's mask as its item takes it: its geometry in the clip's space, `transform` that space's map to output pixels
// of the list, and its feather, a theme length in output pixels, times `scale`, the clip's own scale and its
// animation's at the time. A parent's scale does not grow it (FRAMES-10, FRAMES-20), so `transform` does not.
extension ItemMask {
    // MARK: - Property
    // MARK: - Initializer
    init(
        mask: ResolvedMask,
        transform: AffineTransform,
        scale: Double
    ) {
        self.init(
            geometry: mask.geometry,
            transform: transform,
            feather: mask.feather * scale,
            isInverted: mask.isInverted,
            mode: mask.mode
        )
    }

    // MARK: - Public
    // MARK: - Private
}

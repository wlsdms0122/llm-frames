//
//  ItemMask+ResolvedMask.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// `transform` is the clip's space's map to output pixels of the list. The feather, a theme length in output pixels, is
// multiplied by `scale`, the clip's own scale and its animation's; a parent's scale, which `transform` carries, does
// not grow it.
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

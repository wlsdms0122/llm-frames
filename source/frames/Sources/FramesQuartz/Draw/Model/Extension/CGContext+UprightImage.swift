//
//  CGContext+UprightImage.swift
//  FramesQuartz
//
//  Created by JSilver on 11/17/26.
//

import CoreGraphics

// Drawing an image into a context whose y axis points down, as every context of the renderer is set up, or clipping
// to one.
extension CGContext {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // Draws the image with its top row at the top of `rectangle`.
    func drawUpright(
        _ image: CGImage,
        in rectangle: CGRect
    ) {
        saveGState()
        translateBy(x: rectangle.minX, y: rectangle.maxY)
        scaleBy(x: 1, y: -1)
        draw(image, in: CGRect(x: 0, y: 0, width: rectangle.width, height: rectangle.height))
        restoreGState()
    }

    // Cuts what is drawn after it to `rectangle`, its alpha multiplied by the grey image with its top row at the top of
    // `rectangle`. Restoring the state would drop the clip with it, so the flip that sets the image upright is undone
    // by hand.
    func clipUpright(
        to rectangle: CGRect,
        mask image: CGImage
    ) {
        let flip = CGAffineTransform(translationX: rectangle.minX, y: rectangle.maxY).scaledBy(x: 1, y: -1)
        concatenate(flip)
        clip(to: CGRect(x: 0, y: 0, width: rectangle.width, height: rectangle.height), mask: image)
        concatenate(flip.inverted())
    }

    // MARK: - Private
}

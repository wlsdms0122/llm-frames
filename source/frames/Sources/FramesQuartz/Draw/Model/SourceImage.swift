//
//  SourceImage.swift
//  FramesQuartz
//
//  Created by JSilver on 11/19/26.
//

import CoreGraphics
import Frames

// A picture's source drawn: `size` is the source's own size, in media pixels or a nested list's output pixels, which
// a picture's region is measured in, and `transform` carries those coordinates into the image's pixels, y pointing
// down. A nested list's image and a page's may hold only part of the source, at another scale.
struct SourceImage {
    // MARK: - Property
    let image: CGImage
    let size: CGSize
    let transform: CGAffineTransform

    // MARK: - Initializer
    init(media image: CGImage) {
        self.image = image
        self.size = CGSize(width: image.width, height: image.height)
        self.transform = .identity
    }

    init(
        _ image: CGImage,
        of size: Size,
        drawnOn raster: Raster
    ) {
        self.image = image
        self.size = CGSize(width: size.width, height: size.height)
        self.transform = raster.transform
    }

    init(
        _ image: CGImage,
        of size: CGSize,
        transform: CGAffineTransform
    ) {
        self.image = image
        self.size = size
        self.transform = transform
    }

    // MARK: - Public
    // Draws the image so that the source's coordinates land where the context's current coordinates are.
    func draw(in context: CGContext) {
        context.saveGState()
        context.concatenate(transform.inverted())
        context.drawUpright(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.restoreGState()
    }

    // MARK: - Private
}

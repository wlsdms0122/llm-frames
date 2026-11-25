//
//  SourceImage.swift
//  FramesQuartz
//
//  Created by JSilver on 11/19/26.
//

import CoreGraphics
import CoreImage
import Frames

// A picture's source drawn: `size` is the source's own size, in media pixels or a nested list's output pixels, which
// a picture's region is measured in, and `transform` carries those coordinates into the image's pixels, y pointing
// down. A nested list's image and a page's may hold only part of the source, at another scale. `picture` is the same
// pixels as a Core Image image, its extent at (0, 0): a surface the decoder gave is read where it lies on the GPU.
struct SourceImage {
    // MARK: - Property
    let image: CGImage
    let picture: CIImage
    let size: CGSize
    let transform: CGAffineTransform

    // MARK: - Initializer
    // `image` is `pixels` as a Core Graphics image.
    init(
        media image: CGImage,
        pixels: Pixels
    ) {
        self.image = image
        self.picture = switch pixels {
        case let .surface(surface):
            CIImage(ioSurface: surface.surface, options: [.colorSpace: WorkingSpace.encoded])

        case .bitmap:
            CIImage(cgImage: image)
        }
        self.size = CGSize(width: image.width, height: image.height)
        self.transform = .identity
    }

    init(
        _ image: CGImage,
        of size: Size,
        drawnOn raster: Raster
    ) {
        self.image = image
        self.picture = CIImage(cgImage: image)
        self.size = CGSize(width: size.width, height: size.height)
        self.transform = raster.transform
    }

    init(
        _ image: CGImage,
        of size: CGSize,
        transform: CGAffineTransform
    ) {
        self.image = image
        self.picture = CIImage(cgImage: image)
        self.size = size
        self.transform = transform
    }

    // MARK: - Public
    // MARK: - Private
}

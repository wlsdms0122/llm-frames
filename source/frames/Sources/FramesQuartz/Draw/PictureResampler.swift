//
//  PictureResampler.swift
//  FramesQuartz
//
//  Created by JSilver on 11/25/26.
//

import CoreGraphics
import CoreImage

// Resamples a picture of pixels through an affine map, as every renderer resamples one (FRAMES-21 Rules): each output
// pixel is the mean of the source, each pixel a square of its value and its edge pixels extended outward, over a box
// centred on the image of the pixel's centre, as wide along each of the source's axes as the pixel's image reaches and at
// least one source pixel, times the area of the pixel whose image lies inside the cover, the part of the source the
// picture shows (`ResampleKernelSource`). Both renderers resample by it, `quartz` reading the result back and `metal`
// compositing it on the GPU.
struct PictureResampler {
    // MARK: - Property
    // A side of a cover this far out lies past every source and raster, so it cuts nothing.
    static let unbounded: CGFloat = 0x1p30

    private static let kernelName = "pictureResample"

    private let library: KernelLibrary

    // MARK: - Initializer
    init(library: KernelLibrary = .shared) {
        self.library = library
    }

    // MARK: - Public
    // `source` has its extent's origin at (0, 0), in Core Image's coordinates, rows counted from the bottom. `map` takes
    // those coordinates to the output's, rows counted from the bottom too, and `cover` is the rectangle of the source's
    // coordinates the picture shows, which may reach past the source, where its edge pixels extend. The result is the
    // part of `area`, the output's rectangle drawn, that the cover lands in, its extent whole pixels, and empty where the
    // map does not carry the plane onto itself.
    func resample(
        _ source: CIImage,
        through map: CGAffineTransform,
        covering cover: CGRect,
        within area: CGRect
    ) throws -> CIImage {
        let determinant = map.a * map.d - map.b * map.c
        guard determinant != 0, !source.extent.isEmpty, !cover.isEmpty else { return .empty() }

        let extent = cover.applying(map).integral.intersection(area.integral)
        guard !extent.isNull, !extent.isEmpty else { return .empty() }

        if let landed = wholePixels(of: map, covering: cover, within: extent) {
            return source.clampedToExtent().transformed(by: map).cropped(to: landed)
        }

        let inverse = map.inverted()
        // The box is as wide along each axis as the image of an output pixel reaches along it, and at least one pixel.
        let footprint = CGSize(
            width: max(1, abs(inverse.a) + abs(inverse.c)),
            height: max(1, abs(inverse.b) + abs(inverse.d))
        )
        let reach = CGSize(width: footprint.width / 2 + 1, height: footprint.height / 2 + 1)
        let sampler = CISampler(
            image: source.clampedToExtent(),
            options: [kCISamplerFilterMode: kCISamplerFilterNearest]
        )
        let kernel = try library.kernel(named: Self.kernelName)
        let arguments: [Any] = [
            sampler,
            CIVector(x: inverse.a, y: inverse.c, z: inverse.tx),
            CIVector(x: inverse.b, y: inverse.d, z: inverse.ty),
            CIVector(x: footprint.width, y: footprint.height),
            CIVector(x: cover.minX, y: cover.minY, z: cover.maxX, w: cover.maxY)
        ]
        guard let resampled = kernel.apply(
            extent: extent,
            roiCallback: { _, rectangle in
                rectangle.applying(inverse).insetBy(dx: -reach.width, dy: -reach.height)
            },
            arguments: arguments
        )
        else {
            throw QuartzError.kernelFailed(name: Self.kernelName)
        }

        return resampled
    }

    // The output's pixels the cover lands on, within `area`, where the map moves the source by whole pixels at its own
    // size and the cover's edges land on whole pixels or past the area, which the definition gives as the source's own
    // pixels moved, its edge pixels extended where the cover reaches past it. Nil where the map or the cover's edges
    // do not allow it.
    func wholePixels(
        of map: CGAffineTransform,
        covering cover: CGRect,
        within area: CGRect
    ) -> CGRect? {
        guard
            map.a == 1, map.b == 0, map.c == 0, map.d == 1,
            map.tx == map.tx.rounded(), map.ty == map.ty.rounded()
        else {
            return nil
        }

        let landed = cover.applying(map).intersection(area.integral)
        guard !landed.isNull, !landed.isEmpty else { return nil }

        let isWhole = [landed.minX, landed.minY, landed.maxX, landed.maxY].allSatisfy { $0 == $0.rounded() }

        return isWhole ? landed : nil
    }

    // MARK: - Private
}

//
//  CornerPinWarper.swift
//  FramesQuartz
//
//  Created by JSilver on 11/21/26.
//

import CoreGraphics
import CoreImage
import Frames

// Carries a picture by a homography, as a renderer carries a picture onto its corner pin (FRAMES-27 What a renderer
// holds): each output pixel is the mean of the source over the pixel's image under the inverse map, approximated by
// four by four subsamples read from a box pyramid of the source and cut by its edges' coverage
// (`CornerPinKernelSource`). The source's corners land where the homography takes them, values are averaged as they
// are, and nothing is drawn at or beyond the horizon.
struct CornerPinWarper {
    // MARK: - Property
    private static let halveName = "cornerPinHalve"
    private static let warpName = "cornerPinWarp"
    // The source and six levels above it, the last at 1 / 64 of its size.
    private static let levelCount = 7

    private let library: KernelLibrary

    // MARK: - Initializer
    init(library: KernelLibrary = .shared) {
        self.library = library
    }

    // MARK: - Public
    // `source` is upright, its pixels in y-down coordinates from the top left of its extent, which is whole pixels.
    // `homography` takes those coordinates to the output's pixels, y down. The result is the output's `destination`, a
    // rectangle of whole pixels, as an upright image with its extent's origin at the rectangle's top left: drawn
    // upright in `destination`, it lands where the homography carries the source. Its extent is cut to what the
    // source's reconstruction reaches where the whole source lies in front of the horizon.
    func warp(
        _ source: CIImage,
        through homography: Homography,
        onto destination: CGRect
    ) throws -> CIImage {
        let sourceExtent = source.extent
        let area = CGRect(x: 0, y: 0, width: destination.width, height: destination.height)
        guard !sourceExtent.isEmpty, !sourceExtent.isInfinite, !area.isEmpty else { return .empty() }

        let extent = reach(of: sourceExtent.size, through: homography, onto: destination)
        guard !extent.isNull, !extent.isEmpty else { return .empty() }

        let placed = source.transformed(by: CGAffineTransform(translationX: -sourceExtent.minX, y: -sourceExtent.minY))
        let levels = try pyramid(of: placed)
        // The warp reads a level at points held within one source pixel of its edge, so at most two level pixels past
        // it.
        let extents = levels.map { $0.extent.insetBy(dx: -2, dy: -2) }
        let inverse = homography.inverse
        let height = Double(sourceExtent.height)
        let left = Double(destination.minX)
        let bottom = Double(destination.maxY)
        // The result's point (p, q) is the output's (left + p, bottom - q); the inverse takes it to the source's (u, v),
        // and the source's Core Image point is (u, height - v).
        let rowU = [inverse.a, -inverse.c, inverse.a * left + inverse.c * bottom + inverse.tx]
        let rowV = [inverse.b, -inverse.d, inverse.b * left + inverse.d * bottom + inverse.ty]
        let rowW = [inverse.g, -inverse.h, inverse.g * left + inverse.h * bottom + inverse.i]
        let rowY = zip(rowW, rowV).map { height * $0 - $1 }
        let warp = try library.kernel(named: Self.warpName)
        let arguments: [Any] = levels.map { $0.clampedToExtent() } + [
            CIVector(x: rowU[0], y: rowU[1], z: rowU[2]),
            CIVector(x: rowY[0], y: rowY[1], z: rowY[2]),
            CIVector(x: rowW[0], y: rowW[1], z: rowW[2]),
            CIVector(x: sourceExtent.width, y: sourceExtent.height)
        ]
        guard let carried = warp.apply(
            extent: extent,
            roiCallback: { index, _ in extents[Int(index)] },
            arguments: arguments
        )
        else {
            throw QuartzError.kernelFailed(name: Self.warpName)
        }

        return carried
    }

    // MARK: - Private
    // The part of the result's extent the source's reconstruction can reach: the bounds of the source widened by one
    // pixel and carried, when all of it lies in front of the horizon, and the whole destination otherwise.
    private func reach(
        of size: CGSize,
        through homography: Homography,
        onto destination: CGRect
    ) -> CGRect {
        let area = CGRect(x: 0, y: 0, width: destination.width, height: destination.height)
        let widened = Quad(
            Rectangle(x: -1, y: -1, width: Double(size.width) + 2, height: Double(size.height) + 2)
        )
        guard let carried = homography.apply(to: widened) else { return area }

        let xs = carried.corners.map(\.x)
        let ys = carried.corners.map(\.y)
        let left = xs.min()! - Double(destination.minX)
        let right = xs.max()! - Double(destination.minX)
        let top = Double(destination.maxY) - ys.max()!
        let bottom = Double(destination.maxY) - ys.min()!

        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
            .integral
            .intersection(area)
    }

    // The source and the levels above it, each half the size of the one below, rounded up, and held as an
    // intermediate so the warp reads it as a texture. Each is read with its edge pixels extended outward, and its
    // extent is where it was drawn.
    private func pyramid(of source: CIImage) throws -> [CIImage] {
        let halve = try library.kernel(named: Self.halveName)
        var levels = [source]
        for _ in 1..<Self.levelCount {
            let below = levels[levels.count - 1]
            let extent = CGRect(
                x: 0,
                y: 0,
                width: (below.extent.width / 2).rounded(.up),
                height: (below.extent.height / 2).rounded(.up)
            )
            guard let level = halve.apply(
                extent: extent,
                roiCallback: { _, rect in
                    CGRect(x: rect.minX * 2 - 1, y: rect.minY * 2 - 1, width: rect.width * 2 + 2, height: rect.height * 2 + 2)
                },
                arguments: [below.clampedToExtent()]
            )
            else {
                throw QuartzError.kernelFailed(name: Self.halveName)
            }
            levels.append(level.insertingIntermediate(cache: false))
        }

        return levels
    }
}

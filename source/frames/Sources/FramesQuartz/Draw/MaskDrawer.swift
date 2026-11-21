//
//  MaskDrawer.swift
//  FramesQuartz
//
//  Created by JSilver on 11/18/26.
//

import CoreGraphics
import CoreImage
import Foundation
import Frames

// Draws the masks of an item as one coverage value for each pixel of a region of output pixels, in floating point.
// Each mask is blurred by a Gaussian whose standard deviation is its feather, then inverted when it is. A feathered
// mask is drawn over the region grown on every side by its feather's reach (`ItemMask.featherReach`), so its blur sees
// the geometry past the region's edge: the frame does not cut a mask, and an inverted mask's outside goes on past it.
struct MaskDrawer {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // `region` is in whole pixels of the raster the item's list is drawn on, which the masks' output pixels are carried
    // into, their feather scaled with them. The values are rows from the top.
    func values(
        of masks: [ItemMask],
        over region: CGRect,
        on raster: CGAffineTransform
    ) throws -> [Double] {
        var result = [Double](repeating: masks.first?.mode.startValue ?? 1, count: Int(region.width) * Int(region.height))
        for mask in masks {
            let coverage = try self.coverage(of: mask, over: region, on: raster)
            for index in result.indices {
                let value = Double(coverage[index])
                result[index] = mask.mode.combine(result[index], with: mask.isInverted ? 1 - value : value)
            }
        }

        return result
    }

    // MARK: - Private
    // The mask's blurred coverage at each pixel of the region, rows from the top, before it is inverted.
    private func coverage(
        of mask: ItemMask,
        over region: CGRect,
        on raster: CGAffineTransform
    ) throws -> [Float] {
        let feather = mask.feather * raster.lengthScale
        let margin = feather > 0 ? Int((ItemMask.featherReach * feather).rounded(.up)) : 0
        let width = Int(region.width)
        let height = Int(region.height)
        let drawn = try fill(mask, over: region.insetBy(dx: CGFloat(-margin), dy: CGFloat(-margin)), on: raster)
        guard feather > 0 else { return drawn }

        let image = CIImage(
            bitmapData: drawn.withUnsafeBufferPointer { Data(buffer: $0) },
            bytesPerRow: (width + 2 * margin) * MemoryLayout<Float>.size,
            size: CGSize(width: width + 2 * margin, height: height + 2 * margin),
            format: .Rf,
            colorSpace: nil
        )
        // Outside its extent the drawn image is transparent, so the blur reads 0 coverage there. The margin is even on
        // every side, so the region is the same rectangle whichever way rows are counted.
        let blurred = image.applyingGaussianBlur(sigma: feather)
        var coverage = [Float](repeating: 0, count: width * height)
        coverage.withUnsafeMutableBytes { buffer in
            guard let pointer = buffer.baseAddress else { return }

            WorkingSpace.valueContext.render(
                blurred,
                toBitmap: pointer,
                rowBytes: width * MemoryLayout<Float>.size,
                bounds: CGRect(x: margin, y: margin, width: width, height: height),
                format: .Rf,
                colorSpace: nil
            )
        }

        return coverage
    }

    // The mask's geometry filled white on black over `area` in the raster's pixels, rows from the top.
    private func fill(
        _ mask: ItemMask,
        over area: CGRect,
        on raster: CGAffineTransform
    ) throws -> [Float] {
        let width = Int(area.width)
        let height = Int(area.height)
        var pixels = [Float](repeating: 0, count: width * height)
        try pixels.withUnsafeMutableBytes { buffer in
            guard
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 32,
                    bytesPerRow: width * MemoryLayout<Float>.size,
                    space: CGColorSpace(name: CGColorSpace.linearGray)!,
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                        | CGBitmapInfo.floatComponents.rawValue
                        | CGBitmapInfo.byteOrder32Little.rawValue
                )
            else {
                throw QuartzError.unmadeBitmap(width: width, height: height)
            }

            context.translateBy(x: -area.minX, y: area.maxY)
            context.scaleBy(x: 1, y: -1)
            context.concatenate(raster)
            context.concatenate(CGAffineTransform(mask.transform))
            context.addPath(PathOutline(mask.geometry).fillPath)
            context.setFillColor(gray: 1, alpha: 1)
            context.fillPath(using: .winding)
        }

        return pixels
    }
}

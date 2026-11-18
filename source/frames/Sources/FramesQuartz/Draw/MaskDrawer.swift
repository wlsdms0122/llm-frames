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
// mask is drawn over the region grown on every side by four times its feather, so its blur sees the geometry past the
// region's edge: the frame does not cut a mask, and an inverted mask's outside goes on past it.
struct MaskDrawer {
    // MARK: - Property
    // Past four standard deviations a Gaussian holds less than a ten-thousandth of its weight.
    private static let reach = 4.0

    // MARK: - Initializer
    // MARK: - Public
    // `region` is in output pixels, in whole pixels. The values are rows from the top.
    func values(
        of masks: [ItemMask],
        over region: CGRect
    ) throws -> [Double] {
        var result = [Double](repeating: masks.first?.mode.startValue ?? 1, count: Int(region.width) * Int(region.height))
        for mask in masks {
            let coverage = try self.coverage(of: mask, over: region)
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
        over region: CGRect
    ) throws -> [Float] {
        let margin = mask.feather > 0 ? Int((Self.reach * mask.feather).rounded(.up)) : 0
        let width = Int(region.width)
        let height = Int(region.height)
        let drawn = try fill(mask, over: region.insetBy(dx: CGFloat(-margin), dy: CGFloat(-margin)))
        guard mask.feather > 0 else { return drawn }

        let image = CIImage(
            bitmapData: drawn.withUnsafeBufferPointer { Data(buffer: $0) },
            bytesPerRow: (width + 2 * margin) * MemoryLayout<Float>.size,
            size: CGSize(width: width + 2 * margin, height: height + 2 * margin),
            format: .Rf,
            colorSpace: nil
        )
        // Outside its extent the drawn image is transparent, so the blur reads 0 coverage there. The margin is even on
        // every side, so the region is the same rectangle whichever way rows are counted.
        let blurred = image.applyingGaussianBlur(sigma: mask.feather)
        var coverage = [Float](repeating: 0, count: width * height)
        coverage.withUnsafeMutableBytes { buffer in
            guard let pointer = buffer.baseAddress else { return }

            WorkingSpace.context.render(
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

    // The mask's geometry filled white on black over `area` in output pixels, rows from the top.
    private func fill(
        _ mask: ItemMask,
        over area: CGRect
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
            context.concatenate(CGAffineTransform(mask.transform))
            context.addPath(PathOutline(mask.geometry).fillPath)
            context.setFillColor(gray: 1, alpha: 1)
            context.fillPath(using: .winding)
        }

        return pixels
    }
}

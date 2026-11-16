//
//  RegionSampler.swift
//  FramesPointTracker
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// Reads a region of an image into a grey image of a fixed size, by bilinear interpolation.
struct RegionSampler: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // The region of `size` times `scale` pixels of `image` centred on `centre`, read at `size`. A pixel whose area
    // does not lie wholly in the image is NaN. Where a pixel spans two or more of the image's, the region is read
    // from the image halved, so that interpolation does not skip the pixels between.
    func sample(
        _ image: GreyImage,
        centre: CGPoint,
        size: CGSize,
        scale: Double
    ) -> GreyImage {
        let width = Int(size.width)
        let height = Int(size.height)
        let left = centre.x - size.width * scale / 2
        let top = centre.y - size.height * scale / 2
        var values = [Float](repeating: .nan, count: width * height)
        guard scale < 2 else {
            // Only the part of the image the region covers is halved, cut on even pixels so that it halves as the
            // whole image would.
            let column = max(0, 2 * Int((left / 2).rounded(.down)))
            let row = max(0, 2 * Int((top / 2).rounded(.down)))
            let right = min(image.width, 2 * Int(((left + size.width * scale) / 2).rounded(.up)))
            let bottom = min(image.height, 2 * Int(((top + size.height * scale) / 2).rounded(.up)))
            guard right - column >= 2, bottom - row >= 2 else {
                return GreyImage(width: width, height: height, values: values)
            }
            let part = image.cropped(column: column, row: row, width: right - column, height: bottom - row)
            let centre = CGPoint(x: (centre.x - Double(column)) / 2, y: (centre.y - Double(row)) / 2)

            return sample(part.halved(), centre: centre, size: size, scale: scale / 2)
        }

        image.values.withUnsafeBufferPointer { source in
            values.withUnsafeMutableBufferPointer { values in
                for row in 0..<height {
                    let rowTop = top + Double(row) * scale
                    guard rowTop >= 0, rowTop + scale <= Double(image.height) else { continue }
                    let (above, below, down) = neighbours(rowTop + scale / 2, count: image.height)
                    for column in 0..<width {
                        let columnLeft = left + Double(column) * scale
                        guard columnLeft >= 0, columnLeft + scale <= Double(image.width) else { continue }
                        let (before, after, across) = neighbours(columnLeft + scale / 2, count: image.width)
                        let upper = source[above * image.width + before] * (1 - across)
                            + source[above * image.width + after] * across
                        let lower = source[below * image.width + before] * (1 - across)
                            + source[below * image.width + after] * across
                        values[row * width + column] = upper * (1 - down) + lower * down
                    }
                }
            }
        }

        return GreyImage(width: width, height: height, values: values)
    }

    // MARK: - Private
    // The two pixels along one axis whose centres lie either side of `position`, and how far it lies from the first
    // towards the second. Past the outer pixels' centres both are the outer pixel.
    private func neighbours(
        _ position: Double,
        count: Int
    ) -> (Int, Int, Float) {
        let offset = position - 0.5
        let first = offset.rounded(.down)
        let index = Int(first)

        return (min(max(index, 0), count - 1), min(max(index + 1, 0), count - 1), Float(offset - first))
    }
}

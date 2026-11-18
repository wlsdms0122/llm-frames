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
    // The region of `size` times `scale` pixels of `image` centred on `centre` and turned by `angle` radians clockwise,
    // read at `size` in its own axes. A pixel whose area, as an upright square about where it is read, does not lie
    // wholly in the image is NaN. Where a pixel spans two or more of the image's, the region is read from the image
    // halved, so that interpolation does not skip the pixels between.
    func sample(
        _ image: GreyImage,
        centre: CGPoint,
        size: CGSize,
        scale: Double,
        angle: Double = 0
    ) -> GreyImage {
        let width = Int(size.width)
        let height = Int(size.height)
        let cosine = cos(angle)
        let sine = sin(angle)
        var values = [Float](repeating: .nan, count: width * height)
        guard scale < 2 else {
            // Only the part of the image the region covers is halved, cut on even pixels so that it halves as the
            // whole image would.
            let reachX = scale * (size.width * abs(cosine) + size.height * abs(sine)) / 2
            let reachY = scale * (size.width * abs(sine) + size.height * abs(cosine)) / 2
            let column = max(0, 2 * Int(((centre.x - reachX) / 2).rounded(.down)))
            let row = max(0, 2 * Int(((centre.y - reachY) / 2).rounded(.down)))
            let right = min(image.width, 2 * Int(((centre.x + reachX) / 2).rounded(.up)))
            let bottom = min(image.height, 2 * Int(((centre.y + reachY) / 2).rounded(.up)))
            guard right - column >= 2, bottom - row >= 2 else {
                return GreyImage(width: width, height: height, values: values)
            }
            let part = image.cropped(column: column, row: row, width: right - column, height: bottom - row)
            let centre = CGPoint(x: (centre.x - Double(column)) / 2, y: (centre.y - Double(row)) / 2)

            return sample(part.halved(), centre: centre, size: size, scale: scale / 2, angle: angle)
        }

        // A step of one region pixel along its row and down its column, in image pixels, and where the centre of its
        // top left pixel is read.
        let across = (x: cosine * scale, y: sine * scale)
        let down = (x: -sine * scale, y: cosine * scale)
        let first = (
            x: centre.x + across.x * (0.5 - size.width / 2) + down.x * (0.5 - size.height / 2),
            y: centre.y + across.y * (0.5 - size.width / 2) + down.y * (0.5 - size.height / 2)
        )
        let half = scale / 2
        let imageWidth = Double(image.width)
        let imageHeight = Double(image.height)
        image.values.withUnsafeBufferPointer { source in
            values.withUnsafeMutableBufferPointer { values in
                for row in 0..<height {
                    let rowX = first.x + Double(row) * down.x
                    let rowY = first.y + Double(row) * down.y
                    for column in 0..<width {
                        let x = rowX + Double(column) * across.x
                        let y = rowY + Double(column) * across.y
                        guard
                            x - half >= 0,
                            x + half <= imageWidth,
                            y - half >= 0,
                            y + half <= imageHeight
                        else {
                            continue
                        }
                        let (above, below, downward) = neighbours(y, count: image.height)
                        let (before, after, rightward) = neighbours(x, count: image.width)
                        let upper = source[above * image.width + before] * (1 - rightward)
                            + source[above * image.width + after] * rightward
                        let lower = source[below * image.width + before] * (1 - rightward)
                            + source[below * image.width + after] * rightward
                        values[row * width + column] = upper * (1 - downward) + lower * downward
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

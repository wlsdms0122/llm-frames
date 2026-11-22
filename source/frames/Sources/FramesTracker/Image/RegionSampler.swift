//
//  RegionSampler.swift
//  FramesTracker
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// Reads an image by bilinear interpolation: a region of it into a grey image of a fixed size, or its values at points.
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
                        values[row * width + column] = interpolated(source, of: image, x: x, y: y)
                    }
                }
            }
        }

        return GreyImage(width: width, height: height, values: values)
    }

    // The values of `image` at `points`. A point whose pixel, the upright square of one pixel about it, does not lie
    // wholly in the image is NaN.
    func sample(
        _ image: GreyImage,
        at points: [CGPoint]
    ) -> [Float] {
        let width = Double(image.width)
        let height = Double(image.height)

        return image.values.withUnsafeBufferPointer { source in
            points.map { point in
                guard point.x >= 0.5, point.x <= width - 0.5, point.y >= 0.5, point.y <= height - 0.5 else { return .nan }

                return interpolated(source, of: image, x: point.x, y: point.y)
            }
        }
    }

    // MARK: - Private
    // `source` is the values of `image`.
    private func interpolated(
        _ source: UnsafeBufferPointer<Float>,
        of image: GreyImage,
        x: Double,
        y: Double
    ) -> Float {
        let width = image.width
        let (above, below, downward) = neighbours(y, count: image.height)
        let (before, after, rightward) = neighbours(x, count: width)
        let upper = source[above * width + before] * (1 - rightward) + source[above * width + after] * rightward
        let lower = source[below * width + before] * (1 - rightward) + source[below * width + after] * rightward

        return upper * (1 - downward) + lower * downward
    }

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

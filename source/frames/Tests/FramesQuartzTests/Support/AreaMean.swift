//
//  AreaMean.swift
//  FramesQuartzTests
//
//  Created by JSilver on 11/21/26.
//

import Foundation
import Frames

// The mean FRAMES-27 says a picture carried by a homography approximates, computed on the processor: each output
// pixel is the mean, over the pixel's square, of the source read at the inverse map of each point, the source being
// the bilinear reconstruction of its pixels with each pixel's value at its centre and transparent outside. The mean is
// taken over n × n samples a pixel, n at least 16 and more where neighbouring samples would land over a quarter of a
// source pixel apart. Source and output are premultiplied RGBA in y-down pixels, rows top first.
struct AreaMean {
    // MARK: - Property
    private static let leastCount = 16
    private static let mostCount = 256

    let width: Int
    let height: Int
    let pixels: [Float]

    // MARK: - Initializer
    // The mean of `source` carried by `homography`, which takes the source's pixels to the output's, over an output of
    // `width` by `height` pixels.
    init(
        carrying source: PixelGrid,
        through homography: Homography,
        width: Int,
        height: Int
    ) {
        let inverse = homography.inverse
        let rows = Self.rows(reachedBy: source, through: homography, height: height)
        var pixels = [Float](repeating: 0, count: width * height * 4)
        source.pixels.withUnsafeBufferPointer { buffer in
            nonisolated(unsafe) let sourcePixels = buffer
            pixels.withUnsafeMutableBufferPointer { buffer in
                nonisolated(unsafe) let output = buffer
                DispatchQueue.concurrentPerform(iterations: rows.count) { index in
                    let row = rows.lowerBound + index
                    for column in 0..<width {
                        let value = Self.mean(column: column, row: row, inverse: inverse, of: source, sourcePixels)
                        let start = (row * width + column) * 4
                        output[start] = value.0
                        output[start + 1] = value.1
                        output[start + 2] = value.2
                        output[start + 3] = value.3
                    }
                }
            }
        }

        self.width = width
        self.height = height
        self.pixels = pixels
    }

    // MARK: - Public
    // MARK: - Private
    // The output rows the reconstruction can reach: those around the source's box widened by one source pixel, or every
    // row when part of that box lies at or beyond the horizon.
    private static func rows(
        reachedBy source: PixelGrid,
        through homography: Homography,
        height: Int
    ) -> Range<Int> {
        let widened = Quad(
            Rectangle(x: -1, y: -1, width: Double(source.width + 2), height: Double(source.height + 2))
        )
        guard let carried = homography.apply(to: widened) else { return 0..<height }

        let ys = carried.corners.map(\.y)
        let top = max(0, Int(ys.min()!.rounded(.down)) - 1)
        let bottom = min(height, Int(ys.max()!.rounded(.up)) + 1)

        return top..<max(top, bottom)
    }

    private static func mean(
        column: Int,
        row: Int,
        inverse: Homography,
        of source: PixelGrid,
        _ pixels: UnsafeBufferPointer<Float>
    ) -> (Float, Float, Float, Float) {
        let count = sampleCount(column: column, row: row, inverse: inverse)
        let step = 1 / Double(count)
        var sum = (0.0, 0.0, 0.0, 0.0)
        for sampleRow in 0..<count {
            let y = Double(row) + (Double(sampleRow) + 0.5) * step
            for sampleColumn in 0..<count {
                let x = Double(column) + (Double(sampleColumn) + 0.5) * step
                let w = inverse.g * x + inverse.h * y + inverse.i
                guard w > 0 else { continue }

                let u = (inverse.a * x + inverse.c * y + inverse.tx) / w
                let v = (inverse.b * x + inverse.d * y + inverse.ty) / w
                addBilinear(at: u, v, of: source, pixels, to: &sum)
            }
        }
        let samples = Double(count * count)

        return (Float(sum.0 / samples), Float(sum.1 / samples), Float(sum.2 / samples), Float(sum.3 / samples))
    }

    // Samples a side: at least 16, and enough that neighbouring samples land at most a quarter of a source pixel apart
    // along the pixel's edges carried back.
    private static func sampleCount(
        column: Int,
        row: Int,
        inverse: Homography
    ) -> Int {
        let x = Double(column)
        let y = Double(row)
        let corners = [Point(x: x, y: y), Point(x: x + 1, y: y), Point(x: x + 1, y: y + 1), Point(x: x, y: y + 1)]
            .compactMap { inverse.apply(to: $0) }
        guard corners.count == 4 else { return leastCount }

        let span = (0..<4).map { index in
            let from = corners[index]
            let to = corners[(index + 1) % 4]

            return ((to.x - from.x) * (to.x - from.x) + (to.y - from.y) * (to.y - from.y)).squareRoot()
        }
        .max()!

        return min(mostCount, max(leastCount, Int((4 * span).rounded(.up))))
    }

    // The source's bilinear reconstruction at (u, v), transparent outside, added to `sum`.
    private static func addBilinear(
        at u: Double,
        _ v: Double,
        of source: PixelGrid,
        _ pixels: UnsafeBufferPointer<Float>,
        to sum: inout (Double, Double, Double, Double)
    ) {
        let x = u - 0.5
        let y = v - 0.5
        let left = Int(x.rounded(.down))
        let top = Int(y.rounded(.down))
        let fractionX = x - Double(left)
        let fractionY = y - Double(top)
        addTap(left, top, (1 - fractionX) * (1 - fractionY), of: source, pixels, to: &sum)
        addTap(left + 1, top, fractionX * (1 - fractionY), of: source, pixels, to: &sum)
        addTap(left, top + 1, (1 - fractionX) * fractionY, of: source, pixels, to: &sum)
        addTap(left + 1, top + 1, fractionX * fractionY, of: source, pixels, to: &sum)
    }

    private static func addTap(
        _ column: Int,
        _ row: Int,
        _ weight: Double,
        of source: PixelGrid,
        _ pixels: UnsafeBufferPointer<Float>,
        to sum: inout (Double, Double, Double, Double)
    ) {
        guard weight > 0, column >= 0, row >= 0, column < source.width, row < source.height else { return }

        let start = (row * source.width + column) * 4
        sum.0 += weight * Double(pixels[start])
        sum.1 += weight * Double(pixels[start + 1])
        sum.2 += weight * Double(pixels[start + 2])
        sum.3 += weight * Double(pixels[start + 3])
    }
}

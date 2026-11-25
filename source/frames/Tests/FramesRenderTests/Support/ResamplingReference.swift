//
//  ResamplingReference.swift
//  FramesRenderTests
//
//  Created by JSilver on 11/25/26.
//

import CoreGraphics
import Frames

// The definition of how a renderer resamples a picture of pixels (FRAMES-21 Rules), evaluated in double precision: a
// source shown through `map`, which takes the source's pixels to the output's, both with rows counted from the top, and
// covered by the source's bounds. Each source pixel is a square of its value, its edge pixels extended outward, and an
// output pixel is the mean of the source over the box centred on the image of its centre, as wide along each axis as
// the pixel's image reaches and at least one pixel, times the area of the pixel whose image lies inside the source.
struct ResamplingReference {
    // MARK: - Property
    private let source: Bitmap
    private let inverse: CGAffineTransform
    private let footprint: CGSize

    // MARK: - Initializer
    init(
        source: Bitmap,
        map: CGAffineTransform
    ) {
        self.source = source
        self.inverse = map.inverted()
        self.footprint = CGSize(
            width: max(1, abs(inverse.a) + abs(inverse.c)),
            height: max(1, abs(inverse.b) + abs(inverse.d))
        )
    }

    // MARK: - Public
    // The premultiplied components of output pixel (x, y).
    func pixel(
        x: Int,
        y: Int
    ) -> [Double] {
        let covered = coverage(x: x, y: y)
        guard covered > 0 else { return [0, 0, 0, 0] }

        let centre = CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5).applying(inverse)
        let columns = weights(from: centre.x - footprint.width / 2, to: centre.x + footprint.width / 2, count: source.width)
        let rows = weights(from: centre.y - footprint.height / 2, to: centre.y + footprint.height / 2, count: source.height)
        var sum = [0.0, 0.0, 0.0, 0.0]
        for (row, rowWeight) in rows {
            for (column, columnWeight) in columns {
                let value = source.pixel(x: column, y: row)
                for component in 0..<4 {
                    sum[component] += rowWeight * columnWeight * value[component]
                }
            }
        }
        let total = footprint.width * footprint.height

        return sum.map { $0 / total * covered }
    }

    // The share of output pixel (x, y) whose image lies inside the source.
    func coverage(
        x: Int,
        y: Int
    ) -> Double {
        var polygon = [
            CGPoint(x: x, y: y), CGPoint(x: x + 1, y: y), CGPoint(x: x + 1, y: y + 1), CGPoint(x: x, y: y + 1)
        ]
        .map { $0.applying(inverse) }
        let whole = area(of: polygon)
        polygon = cut(polygon, axis: \.x, atLeast: 0)
        polygon = cut(polygon, axis: \.y, atLeast: 0)
        polygon = cut(polygon, axis: \.x, atMost: Double(source.width))
        polygon = cut(polygon, axis: \.y, atMost: Double(source.height))

        return area(of: polygon) / whole
    }

    // MARK: - Private
    // Each source pixel the box from `low` to `high` along one axis reaches, held to the source, with the length of its
    // square inside the box.
    private func weights(
        from low: Double,
        to high: Double,
        count: Int
    ) -> [(Int, Double)] {
        Array(Int(low.rounded(.down))..<Int(high.rounded(.up))).compactMap { index in
            let length = min(high, Double(index + 1)) - max(low, Double(index))
            guard length > 0 else { return nil }

            return (min(max(index, 0), count - 1), length)
        }
    }

    private func cut(
        _ polygon: [CGPoint],
        axis: KeyPath<CGPoint, CGFloat>,
        atLeast limit: Double
    ) -> [CGPoint] {
        cut(polygon) { $0[keyPath: axis] - limit }
    }

    private func cut(
        _ polygon: [CGPoint],
        axis: KeyPath<CGPoint, CGFloat>,
        atMost limit: Double
    ) -> [CGPoint] {
        cut(polygon) { limit - $0[keyPath: axis] }
    }

    // The part of the convex polygon where `depth` is at least 0.
    private func cut(
        _ polygon: [CGPoint],
        depth: (CGPoint) -> Double
    ) -> [CGPoint] {
        var kept: [CGPoint] = []
        for (index, from) in polygon.enumerated() {
            let to = polygon[(index + 1) % polygon.count]
            let depthFrom = depth(from)
            let depthTo = depth(to)
            if depthFrom >= 0 { kept.append(from) }
            if (depthFrom >= 0) != (depthTo >= 0) {
                let share = depthFrom / (depthFrom - depthTo)
                kept.append(CGPoint(x: from.x + (to.x - from.x) * share, y: from.y + (to.y - from.y) * share))
            }
        }

        return kept
    }

    private func area(of polygon: [CGPoint]) -> Double {
        guard polygon.count > 2 else { return 0 }

        let twice = polygon.indices.reduce(0.0) { sum, index in
            let from = polygon[index]
            let to = polygon[(index + 1) % polygon.count]

            return sum + from.x * to.y - to.x * from.y
        }

        return abs(twice) / 2
    }
}

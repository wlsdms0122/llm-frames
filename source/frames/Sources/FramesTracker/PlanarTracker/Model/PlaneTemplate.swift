//
//  PlaneTemplate.swift
//  FramesTracker
//
//  Created by JSilver on 11/22/26.
//

import Foundation
import Frames

// The template of one pyramid level: the pixels of the level whose centres lie inside the target's quad on the
// target's frame, thinned on a grid to at most `maximumCount`. Each keeps its position in normalised coordinates,
// centred on the quad's centroid in units of half its mean side, its value, and its steepest descent image, the
// gradient of the template times the Jacobian of the homography at the identity, one value for each of its eight
// parameters. A pixel with a neighbour outside the picture takes no part.
struct PlaneTemplate: Sendable {
    // MARK: - Property
    // In normalised coordinates.
    let xs: [Double]
    let ys: [Double]
    let values: [Double]
    // Eight rows, one for each parameter of the homography, of one value for each pixel.
    let steepestDescent: [[Double]]

    var count: Int {
        values.count
    }

    // MARK: - Initializer
    // `quad`, `centroid` and `scale` are in the level's pixels.
    init(
        image: GreyImage,
        quad: [CGPoint],
        centroid: CGPoint,
        scale: Double,
        maximumCount: Int
    ) {
        let cornerXs = quad.map(\.x)
        let cornerYs = quad.map(\.y)
        let left = max(1, Int((cornerXs.min() ?? 0).rounded(.down)))
        let right = min(image.width - 2, Int((cornerXs.max() ?? 0).rounded(.down)))
        let top = max(1, Int((cornerYs.min() ?? 0).rounded(.down)))
        let bottom = min(image.height - 2, Int((cornerYs.max() ?? 0).rounded(.down)))
        var pixels: [(x: Int, y: Int)] = []
        if left <= right, top <= bottom {
            for y in top...bottom {
                for x in left...right where Self.isInside(quad, CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5)) {
                    pixels.append((x, y))
                }
            }
        }
        let stride = max(1, Int((Double(pixels.count) / Double(maximumCount)).squareRoot().rounded(.up)))
        if stride > 1 {
            pixels = pixels.filter { $0.x % stride == 0 && $0.y % stride == 0 }
        }

        var xs: [Double] = []
        var ys: [Double] = []
        var values: [Double] = []
        var steepestDescent = [[Double]](repeating: [], count: 8)
        for (x, y) in pixels {
            let value = image.value(x: x, y: y)
            let left = image.value(x: x - 1, y: y)
            let right = image.value(x: x + 1, y: y)
            let above = image.value(x: x, y: y - 1)
            let below = image.value(x: x, y: y + 1)
            guard !value.isNaN, !left.isNaN, !right.isNaN, !above.isNaN, !below.isNaN else { continue }

            // The gradient in normalised coordinates, by central differences.
            let gradientX = Double(right - left) / 2 * scale
            let gradientY = Double(below - above) / 2 * scale
            let normalisedX = (Double(x) + 0.5 - centroid.x) / scale
            let normalisedY = (Double(y) + 0.5 - centroid.y) / scale
            let radial = gradientX * normalisedX + gradientY * normalisedY
            xs.append(normalisedX)
            ys.append(normalisedY)
            values.append(Double(value))
            steepestDescent[0].append(gradientX * normalisedX)
            steepestDescent[1].append(gradientX * normalisedY)
            steepestDescent[2].append(gradientX)
            steepestDescent[3].append(gradientY * normalisedX)
            steepestDescent[4].append(gradientY * normalisedY)
            steepestDescent[5].append(gradientY)
            steepestDescent[6].append(-normalisedX * radial)
            steepestDescent[7].append(-normalisedY * radial)
        }

        self.xs = xs
        self.ys = ys
        self.values = values
        self.steepestDescent = steepestDescent
    }

    // MARK: - Public
    // MARK: - Private
    // Whether `point` lies strictly inside the convex quad, on the same side of each of its edges.
    private static func isInside(
        _ quad: [CGPoint],
        _ point: CGPoint
    ) -> Bool {
        let sides = quad.indices.map { index in
            let start = quad[index]
            let end = quad[(index + 1) % quad.count]
            return (end.x - start.x) * (point.y - start.y) - (end.y - start.y) * (point.x - start.x)
        }

        return sides.allSatisfy { $0 > 0 } || sides.allSatisfy { $0 < 0 }
    }
}

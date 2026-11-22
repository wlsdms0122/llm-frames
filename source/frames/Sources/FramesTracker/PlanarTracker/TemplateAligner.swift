//
//  TemplateAligner.swift
//  FramesTracker
//
//  Created by JSilver on 11/22/26.
//

import Accelerate
import Foundation
import Frames
import simd

// Aligns a target's template, taken on the target's frame, to another frame by the inverse compositional
// Lucas-Kanade algorithm: Gauss-Newton on the eight parameters of a homography, coarse to fine over the two frames'
// image pyramids. Each iteration fits a gain and a bias of the frame against the template by weighted least squares,
// so a change of brightness or contrast does not move the fit, and weighs each pixel by iteratively reweighted least
// squares: Huber's weights until the update settles, then Tukey's biweights from there, which give 0 to the pixels
// that do not match, such as those of something in front of the target.
struct TemplateAligner: Sendable {
    // MARK: - Property
    // The top level keeps at least `minimumSide` of its pixels along the target's short side.
    private static let minimumSide = 24.0
    private static let maximumLevels = 5
    private static let maximumCount = 20000
    // A phase ends when an update moves no corner of the target by more than `settled` pixels of the template's level,
    // or after `maximumIterations`.
    private static let maximumIterations = 30
    private static let settled = 0.02
    // The residuals' scale is 1.4826 times their median absolute value, which estimates their standard deviation under
    // Gaussian noise, and at least `noiseFloor`, one step of 8 bits.
    private static let noiseFloor = 1.0 / 255

    // The highest level of the pyramid a frame is aligned on.
    let levels: Int

    // One for each level, from 0.
    private let templates: [PlaneTemplate]
    // From the templates' normalised coordinates to media pixels.
    private let normalisation: simd_double3x3
    private let sampler = RegionSampler()

    // MARK: - Initializer
    // Nil when a level of the template holds fewer pixels than the homography has parameters.
    init?(
        target: Quad,
        on image: GreyImage
    ) {
        let corners = target.corners.map { CGPoint(x: $0.x, y: $0.y) }
        let sides = corners.indices.map { index in
            let next = corners[(index + 1) % corners.count]
            return hypot(next.x - corners[index].x, next.y - corners[index].y)
        }
        let short = min((sides[0] + sides[2]) / 2, (sides[1] + sides[3]) / 2)
        let scale = sides.reduce(0, +) / 8
        let centroid = CGPoint(x: target.centroid.x, y: target.centroid.y)
        var levels = 0
        while levels < Self.maximumLevels, short / pow(2, Double(levels + 1)) >= Self.minimumSide {
            levels += 1
        }

        let templates = image.pyramid(levels: levels).enumerated().map { level, image in
            let factor = pow(2, Double(level))
            return PlaneTemplate(
                image: image,
                quad: corners.map { CGPoint(x: $0.x / factor, y: $0.y / factor) },
                centroid: CGPoint(x: centroid.x / factor, y: centroid.y / factor),
                scale: scale / factor,
                maximumCount: Self.maximumCount
            )
        }
        guard templates.allSatisfy({ $0.count >= 8 }) else { return nil }

        self.levels = levels
        self.templates = templates
        self.normalisation = simd_double3x3(rows: [
            simd_double3(scale, 0, centroid.x),
            simd_double3(0, scale, centroid.y),
            simd_double3(0, 0, 1)
        ])
    }

    // MARK: - Public
    // The template aligned on `pyramid`, a frame's levels from 0 to `levels`, from `guess`, the homography from the
    // target's frame to that frame in media pixels. Where `guess` shrinks the target to half or less, the finest levels
    // of the template are left out and each other is aligned on the frame's level one finer for each halving, so a
    // template pixel spans about one pixel of the frame. Nil where fewer than half the template's pixels land inside
    // the frame.
    func align(
        on pyramid: [GreyImage],
        from guess: simd_double3x3
    ) -> PlaneAlignment? {
        let shift = finerLevels(under: guess)
        var alignment = PlaneAlignment(homography: guess, correlation: 0, inlierRatio: 0)
        for level in stride(from: levels, through: shift, by: -1) {
            let imageLevel = level - shift
            guard
                let refined = refine(alignment.homography, level: level, on: pyramid[imageLevel], imageLevel: imageLevel)
            else {
                return nil
            }
            alignment = refined
        }

        return alignment
    }

    // MARK: - Private
    // The template of `level` aligned on `image`, the frame's level `imageLevel`, from `homography`, and its correlation
    // and inliers there.
    private func refine(
        _ homography: simd_double3x3,
        level: Int,
        on image: GreyImage,
        imageLevel: Int
    ) -> PlaneAlignment? {
        let template = templates[level]
        let toImage = scaling(1 / pow(2, Double(imageLevel)))
        let cornerScale = normalisation[0][0] / pow(2, Double(level))
        var warp = toImage * homography * normalisation
        var weights = [Double](repeating: 1, count: template.count)
        var warped: [Double] = []
        var estimator = MEstimator.huber
        var iterations = 0
        while true {
            warped = values(of: image, under: warp, at: template)
            let isInside = warped.map { !$0.isNaN }
            guard isInside.filter({ $0 }).count * 2 >= template.count else { return nil }
            for index in warped.indices where !isInside[index] {
                warped[index] = 0
                weights[index] = 0
            }

            let (gain, bias) = photometricFit(of: warped, to: template.values, weights: weights)
            let residuals = vDSP.add(-bias, vDSP.subtract(warped, vDSP.multiply(gain, template.values)))
            var magnitudes = residuals.indices.filter { isInside[$0] }.map { abs(residuals[$0]) }
            vDSP.sort(&magnitudes, sortOrder: .ascending)
            let scale = max(1.4826 * magnitudes[magnitudes.count / 2], Self.noiseFloor)
            weights = residuals.indices.map { index in
                isInside[index] ? estimator.weight(of: residuals[index], scale: scale) : 0
            }

            guard let increment = gaussNewtonStep(template, residuals: residuals, weights: weights) else { break }
            let update = matrix(of: increment.map { $0 / gain })
            warp = warp * update.inverse
            iterations += 1

            if largestCornerMove(of: update) * cornerScale < Self.settled || iterations == Self.maximumIterations {
                guard estimator == .huber else { break }

                estimator = .tukey
                iterations = 0
            }
        }

        let inliers = weights.indices.filter { weights[$0] > 0 }
        return PlaneAlignment(
            homography: normalised(toImage.inverse * warp * normalisation.inverse),
            correlation: correlation(inliers.map { template.values[$0] }, inliers.map { warped[$0] }),
            inlierRatio: Double(inliers.count) / Double(template.count)
        )
    }

    // The frame's values at the template's pixels carried by `warp`, from normalised coordinates to the frame's
    // pixels. A pixel carried behind the horizon is outside the frame, and NaN.
    private func values(
        of image: GreyImage,
        under warp: simd_double3x3,
        at template: PlaneTemplate
    ) -> [Double] {
        let points = zip(template.xs, template.ys).map { x, y in
            let carried = warp * simd_double3(x, y, 1)
            guard carried.z > 0 else { return CGPoint(x: Double.nan, y: .nan) }

            return CGPoint(x: carried.x / carried.z, y: carried.y / carried.z)
        }

        return vDSP.floatToDouble(sampler.sample(image, at: points))
    }

    // The gain and bias that take the template's values closest to the frame's, by weighted least squares. A
    // template of one value takes a gain of 1.
    private func photometricFit(
        of warped: [Double],
        to values: [Double],
        weights: [Double]
    ) -> (gain: Double, bias: Double) {
        let weighted = vDSP.multiply(weights, values)
        let total = vDSP.sum(weights)
        let templateSum = vDSP.sum(weighted)
        let frameSum = vDSP.dot(weights, warped)
        let variance = vDSP.dot(weighted, values) - templateSum * templateSum / total
        let covariance = vDSP.dot(weighted, warped) - templateSum * frameSum / total
        let gain = variance > 1e-12 ? covariance / variance : 1

        return (gain, (frameSum - gain * templateSum) / total)
    }

    // The increment of the eight parameters that the weighted normal equations of the steepest descent images give,
    // nil where they have no one solution.
    private func gaussNewtonStep(
        _ template: PlaneTemplate,
        residuals: [Double],
        weights: [Double]
    ) -> [Double]? {
        let weighted = template.steepestDescent.map { vDSP.multiply(weights, $0) }
        var hessian = [Double](repeating: 0, count: 64)
        for row in 0..<8 {
            for column in row..<8 {
                let value = vDSP.dot(weighted[row], template.steepestDescent[column])
                hessian[row * 8 + column] = value
                hessian[column * 8 + row] = value
            }
        }

        return solve(hessian, weighted.map { vDSP.dot($0, residuals) })
    }

    // The solution of the symmetric system `matrix` x = `vector` by Cholesky factorisation, nil where `matrix` is not
    // positive definite.
    private func solve(
        _ matrix: [Double],
        _ vector: [Double]
    ) -> [Double]? {
        let size = vector.count
        var lower = [Double](repeating: 0, count: size * size)
        for row in 0..<size {
            for column in 0...row {
                var sum = matrix[row * size + column]
                for index in 0..<column {
                    sum -= lower[row * size + index] * lower[column * size + index]
                }
                if row == column {
                    guard sum > 0 else { return nil }
                    lower[row * size + row] = sum.squareRoot()
                } else {
                    lower[row * size + column] = sum / lower[column * size + column]
                }
            }
        }

        var forward = vector
        for row in 0..<size {
            for index in 0..<row {
                forward[row] -= lower[row * size + index] * forward[index]
            }
            forward[row] /= lower[row * size + row]
        }
        var solution = forward
        for row in stride(from: size - 1, through: 0, by: -1) {
            for index in (row + 1)..<size {
                solution[row] -= lower[index * size + row] * solution[index]
            }
            solution[row] /= lower[row * size + row]
        }

        return solution
    }

    // The homography of the parameters, ((1 + p0) x + p1 y + p2, p3 x + (1 + p4) y + p5) / (p6 x + p7 y + 1).
    private func matrix(of parameters: [Double]) -> simd_double3x3 {
        simd_double3x3(rows: [
            simd_double3(1 + parameters[0], parameters[1], parameters[2]),
            simd_double3(parameters[3], 1 + parameters[4], parameters[5]),
            simd_double3(parameters[6], parameters[7], 1)
        ])
    }

    // How far `update` moves the corners of the square from -1 to 1, the target's corners about in normalised
    // coordinates.
    private func largestCornerMove(of update: simd_double3x3) -> Double {
        [(-1.0, -1.0), (1, -1), (1, 1), (-1, 1)]
            .map { x, y in
                let carried = update * simd_double3(x, y, 1)
                return hypot(carried.x / carried.z - x, carried.y / carried.z - y)
            }
            .max() ?? 0
    }

    // The zero-mean normalised cross-correlation of two lists of values, 0 where either is of one value.
    private func correlation(
        _ values: [Double],
        _ others: [Double]
    ) -> Double {
        guard !values.isEmpty else { return 0 }

        let count = Double(values.count)
        let sum = vDSP.sum(values)
        let otherSum = vDSP.sum(others)
        let covariance = vDSP.dot(values, others) - sum * otherSum / count
        let variance = vDSP.dot(values, values) - sum * sum / count
        let otherVariance = vDSP.dot(others, others) - otherSum * otherSum / count
        guard variance > 0, otherVariance > 0 else { return 0 }

        return covariance / (variance * otherVariance).squareRoot()
    }

    // How many levels finer than each template level the frame is read on under `homography`: one for each halving
    // of lengths about the target's centroid, past the first, up to `levels`.
    private func finerLevels(under homography: simd_double3x3) -> Int {
        let centroid = normalisation[2]
        let steps = [centroid, centroid + simd_double3(1, 0, 0), centroid + simd_double3(0, 1, 0)].map { point in
            let carried = homography * point
            return simd_double2(carried.x / carried.z, carried.y / carried.z)
        }
        let across = steps[1] - steps[0]
        let down = steps[2] - steps[0]
        let factor = abs(across.x * down.y - across.y * down.x).squareRoot()
        guard factor < 0.5 else { return 0 }

        return min(levels, Int(log2(1 / factor).rounded(.down)))
    }

    private func scaling(_ factor: Double) -> simd_double3x3 {
        simd_double3x3(diagonal: simd_double3(factor, factor, 1))
    }

    // `homography` scaled to 1 at its bottom right.
    private func normalised(_ homography: simd_double3x3) -> simd_double3x3 {
        homography * (1 / homography[2][2])
    }
}

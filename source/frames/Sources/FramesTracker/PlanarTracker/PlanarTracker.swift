//
//  PlanarTracker.swift
//  FramesTracker
//
//  Created by JSilver on 11/22/26.
//

import Foundation
import Frames
import simd

// The `planar` tracker: the homography of the plane the target lies on, found on each frame by aligning the target's
// template, taken on its own frame, run from that frame forwards and, from it again, backwards over the analysis
// pictures the decoder reads by index. Each frame is aligned to the target's own frame, so errors do not build up
// from frame to frame, and the quad reported is the target's corners carried by the homography. The target is lost on
// the first frame where the correlation over the template's inliers falls below `lostCorrelation` or its inliers fall
// below `minimumInlierRatio` of its pixels, which ends that direction.
package struct PlanarTracker: Sendable {
    // MARK: - Property
    package static let lostCorrelation = 0.8
    // The residuals' scale grows with the share of the target covered, and so does the band of residuals the robust
    // weights keep. Past about a third covered the band takes in the cover, and a wrong alignment then keeps more
    // pixels and correlates above `lostCorrelation` on them. Below this share the target is lost before that.
    package static let minimumInlierRatio = 0.7

    private let decoder: any MediaDecoder

    // MARK: - Initializer
    package init(decoder: any MediaDecoder) {
        self.decoder = decoder
    }

    // MARK: - Public
    // MARK: - Private
    // The target on each of `indices` in turn, out to the frame it is lost on. Each frame is aligned first from the
    // constant-velocity prediction, the change from the frame before last to the last frame applied once more after
    // the last frame's homography, and then from the last frame's homography. The first alignment that finds the
    // target is taken.
    private func follow(
        _ target: Quad,
        in file: MediaFile,
        reading: PictureReading,
        from start: Int,
        over indices: [Int]
    ) throws -> [TrackedFrame] {
        guard let aligner = TemplateAligner(target: target, on: try image(of: file, atFrame: start, reading: reading)) else {
            return []
        }

        var last = matrix_identity_double3x3
        var beforeLast: simd_double3x3?
        var frames: [TrackedFrame] = []
        for index in indices {
            let pyramid = try image(of: file, atFrame: index, reading: reading).pyramid(levels: aligner.levels)
            let kept = beforeLast.map { before in last * before.inverse * last }
            let found = [kept, last].compactMap { $0 }.lazy
                .compactMap { aligner.align(on: pyramid, from: $0) }
                .first { $0.correlation >= Self.lostCorrelation && $0.inlierRatio >= Self.minimumInlierRatio }
            guard let found, let quad = carried(target, by: found.homography) else { break }

            frames.append(TrackedFrame(time: file.frameTimes[index], quad: quad))
            beforeLast = last
            last = found.homography
        }

        return frames
    }

    // Each corner of `quad` carried by `homography`, nil where one lies behind its horizon.
    private func carried(
        _ quad: Quad,
        by homography: simd_double3x3
    ) -> Quad? {
        let corners = quad.corners.compactMap { corner -> Point? in
            let carried = homography * simd_double3(corner.x, corner.y, 1)
            guard carried.z > 0 else { return nil }

            return Point(x: carried.x / carried.z, y: carried.y / carried.z)
        }
        guard corners.count == 4 else { return nil }

        return Quad(topLeft: corners[0], topRight: corners[1], bottomRight: corners[2], bottomLeft: corners[3])
    }

    private func image(
        of file: MediaFile,
        atFrame index: Int,
        reading: PictureReading
    ) throws -> GreyImage {
        GreyImage(picture: try decoder.picture(of: file, atFrame: index, reading: reading))
    }
}

extension PlanarTracker: TrackerProvider {
    // MARK: - Lifecycle
    package func track(
        _ target: Quad,
        in file: MediaFile,
        atMediaTime time: Double,
        over range: ClosedRange<Double>,
        colorSpace: ColorSpace?
    ) throws -> [TrackedFrame] {
        let start = file.frameIndex(at: time)
        let times = file.frameTimes
        guard times.indices.contains(start) else { return [] }
        let after = times.indices.filter { $0 > start && range.contains(times[$0]) }
        let before = times.indices.filter { $0 < start && range.contains(times[$0]) }.reversed()

        let reading = PictureReading.analysis(colorSpace: colorSpace)
        let forward = try follow(target, in: file, reading: reading, from: start, over: after)
        let backward = try follow(target, in: file, reading: reading, from: start, over: Array(before))

        return backward.reversed() + [TrackedFrame(time: times[start], quad: target)] + forward
    }
}

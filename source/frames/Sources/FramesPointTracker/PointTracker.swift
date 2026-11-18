//
//  PointTracker.swift
//  FramesPointTracker
//
//  Created by JSilver on 11/16/26.
//

import Foundation
import Frames

// The `point` tracker: two-point tracking by template matching, run from the target's frame forwards and, from it
// again, backwards over the frames the decoder reads by index. A track point sits near each end of the target's long
// side, and the two points found on a frame give the target's move, scale and rotation there, the similarity that
// carries the target's quad to the quad reported. The target is lost on the first frame where either point's
// correlation with its feature falls below `lostCorrelation`, which ends that direction.
package struct PointTracker: Sendable {
    // MARK: - Property
    package static let lostCorrelation = 0.8

    // Each frame is matched again with the features read at the scale and angle the pass before found, until a pass
    // moves no point by more than `settled` pixels or `maximumPasses` have run: a turn the guess missed is closed in a
    // few passes, and a frame the guess already fits takes one or two.
    private static let maximumPasses = 5
    private static let settled = 0.1
    private static let featureMargin = 0.6

    private let decoder: any MediaDecoder

    // MARK: - Initializer
    package init(decoder: any MediaDecoder) {
        self.decoder = decoder
    }

    // MARK: - Public
    // MARK: - Private
    // The target on each of `indices` in turn, out to the frame it is lost on. Each frame is matched from where the
    // points would be if they kept the move of the last two frames, and then, if that does not find the target, from
    // where they were on the last frame.
    private func follow(
        _ target: Quad,
        in file: MediaFile,
        from start: Int,
        over indices: [Int]
    ) throws -> [TrackedFrame] {
        let facing = TargetFacing(target)
        guard let points = trackPoints(of: facing, on: try image(of: file, atFrame: start)) else { return [] }
        let starts = points.map(\.point)

        var last = TrackEstimate(points: starts, correlation: 1)
        var beforeLast: TrackEstimate?
        var frames: [TrackedFrame] = []
        for index in indices {
            let image = try image(of: file, atFrame: index)
            let moved = beforeLast.map { before in
                zip(last.points, before.points).map { point, earlier in
                    CGPoint(x: 2 * point.x - earlier.x, y: 2 * point.y - earlier.y)
                }
            }

            var found: TrackEstimate?
            for guess in [moved, last.points].compactMap({ $0 }) {
                guard let estimate = estimate(on: image, of: points, from: guess, facing: facing) else { continue }
                if found.map({ estimate.correlation > $0.correlation }) ?? true { found = estimate }
                if estimate.correlation >= Self.lostCorrelation { break }
            }
            guard let found, found.correlation >= Self.lostCorrelation else { break }

            let motion = self.motion(from: starts, to: found.points)
            guard motion.scale > 0 else { break }

            frames.append(TrackedFrame(time: file.frameTimes[index], quad: target.applying(motion.transform)))
            beforeLast = last
            last = found
        }

        return frames
    }

    // The track points on `image` from `guess`, each pass reading the features at the scale and angle the points the
    // pass before found give against where they are on the target's frame.
    private func estimate(
        on image: GreyImage,
        of points: [TrackPoint],
        from guess: [CGPoint],
        facing: TargetFacing
    ) -> TrackEstimate? {
        let starts = points.map(\.point)
        var located = guess
        var matches: [TrackPointMatch] = []
        for _ in 0..<Self.maximumPasses {
            let motion = self.motion(from: starts, to: located)
            let angle = facing.angle + motion.rotation * .pi / 180
            matches = zip(points, located).compactMap { point, expected in
                point.find(in: image, near: expected, scale: motion.scale, angle: angle)
            }
            guard matches.count == points.count else { return nil }

            let found = matches.map(\.point)
            let step = zip(found, located).map { hypot($0.x - $1.x, $0.y - $1.y) }.max() ?? 0
            located = found
            if step <= Self.settled { break }
        }

        return TrackEstimate(points: located, correlation: matches.map(\.correlation).min() ?? 0)
    }

    // A track point near each end of the target's long side. Each feature, read in the target's own axes, reaches
    // `featureMargin` short sides past the target and holds up to three times its short side along it, so the two
    // features hold different parts of a long target and their distance measures its scale and their direction its
    // rotation.
    private func trackPoints(
        of facing: TargetFacing,
        on image: GreyImage
    ) -> [TrackPoint]? {
        let isWide = facing.width >= facing.height
        let long = max(facing.width, facing.height)
        let short = min(facing.width, facing.height)
        let reach = min(long / 2, 3 * short)
        let along = (reach + 2 * Self.featureMargin * short).rounded(.up)
        let across = (short + 2 * Self.featureMargin * short).rounded(.up)
        let size = isWide ? CGSize(width: along, height: across) : CGSize(width: across, height: along)

        // The long side runs along the target's top edge when it is wide, and down its left edge when it is tall.
        let offset = (long - reach) / 2
        let direction = isWide
            ? Point(x: cos(facing.angle), y: sin(facing.angle))
            : Point(x: -sin(facing.angle), y: cos(facing.angle))
        let ends = [-offset, offset].map { offset in
            CGPoint(x: facing.centre.x + offset * direction.x, y: facing.centre.y + offset * direction.y)
        }
        let points = ends.compactMap { TrackPoint(at: $0, size: size, angle: facing.angle, in: image) }

        return points.count == ends.count ? points : nil
    }

    // The similarity the track points give from where they are on the target's frame.
    private func motion(
        from starts: [CGPoint],
        to ends: [CGPoint]
    ) -> TrackMotion {
        TrackMotion(from: starts.map { Point(x: $0.x, y: $0.y) }, to: ends.map { Point(x: $0.x, y: $0.y) })
    }

    private func image(
        of file: MediaFile,
        atFrame index: Int
    ) throws -> GreyImage {
        GreyImage(picture: try decoder.picture(of: file, atFrame: index))
    }
}

extension PointTracker: TrackerProvider {
    // MARK: - Lifecycle
    package func track(
        _ target: Quad,
        in file: MediaFile,
        atMediaTime time: Double,
        over range: ClosedRange<Double>
    ) throws -> [TrackedFrame] {
        let start = file.frameIndex(at: time)
        let times = file.frameTimes
        guard times.indices.contains(start) else { return [] }
        let after = times.indices.filter { $0 > start && range.contains(times[$0]) }
        let before = times.indices.filter { $0 < start && range.contains(times[$0]) }.reversed()

        let forward = try follow(target, in: file, from: start, over: after)
        let backward = try follow(target, in: file, from: start, over: Array(before))

        return backward.reversed() + [TrackedFrame(time: times[start], quad: target)] + forward
    }
}

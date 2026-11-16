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
// side, and the two points found on a frame give the target's move and scale there. The target is lost on the first
// frame where either point's correlation with its feature falls below `lostCorrelation`, which ends that direction.
package struct PointTracker: Sendable {
    // MARK: - Property
    package static let lostCorrelation = 0.8

    // Each frame is matched twice, the second time with the features read at the scale the first found.
    private static let passes = 2
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
        _ target: Rectangle,
        in file: MediaFile,
        from start: Int,
        over indices: [Int]
    ) throws -> [TrackedFrame] {
        guard let points = trackPoints(of: target, on: try image(of: file, atFrame: start)) else { return [] }
        let span = distance(points[0].point, points[1].point)

        var last = TrackEstimate(points: points.map(\.point), scale: 1, correlation: 1)
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
                guard let estimate = estimate(on: image, of: points, from: guess, scale: last.scale, span: span)
                else {
                    continue
                }
                if found.map({ estimate.correlation > $0.correlation }) ?? true { found = estimate }
                if estimate.correlation >= Self.lostCorrelation { break }
            }
            guard let found, found.correlation >= Self.lostCorrelation, found.scale > 0 else { break }

            // The points sit either side of the target's centre, so it lies midway between them.
            let centre = midpoint(found.points[0], found.points[1])
            let width = target.width * found.scale
            let height = target.height * found.scale
            let rectangle = Rectangle(x: centre.x - width / 2, y: centre.y - height / 2, width: width, height: height)
            frames.append(TrackedFrame(time: file.frameTimes[index], rectangle: rectangle))
            beforeLast = last
            last = found
        }

        return frames
    }

    // The track points on `image` from `guess`, each pass reading the features at the scale the one before found.
    private func estimate(
        on image: GreyImage,
        of points: [TrackPoint],
        from guess: [CGPoint],
        scale: Double,
        span: Double
    ) -> TrackEstimate? {
        var located = guess
        var scale = scale
        var matches: [TrackPointMatch] = []
        for _ in 0..<Self.passes {
            matches = zip(points, located).compactMap { point, expected in
                point.find(in: image, near: expected, scale: scale)
            }
            guard matches.count == points.count else { return nil }

            located = matches.map(\.point)
            scale = distance(located[0], located[1]) / span
        }

        return TrackEstimate(points: located, scale: scale, correlation: matches.map(\.correlation).min() ?? 0)
    }

    // A track point near each end of the target's long side. Each feature reaches `featureMargin` short sides past
    // the target and holds up to three times its short side along it, so the two features hold different parts of a
    // long target and their distance measures its scale.
    private func trackPoints(
        of target: Rectangle,
        on image: GreyImage
    ) -> [TrackPoint]? {
        let isWide = target.width >= target.height
        let long = max(target.width, target.height)
        let short = min(target.width, target.height)
        let reach = min(long / 2, 3 * short)
        let along = (reach + 2 * Self.featureMargin * short).rounded(.up)
        let across = (short + 2 * Self.featureMargin * short).rounded(.up)
        let size = isWide ? CGSize(width: along, height: across) : CGSize(width: across, height: along)

        let offset = (long - reach) / 2
        let centre = CGPoint(x: target.x + target.width / 2, y: target.y + target.height / 2)
        let ends = [-offset, offset].map { offset in
            isWide ? CGPoint(x: centre.x + offset, y: centre.y) : CGPoint(x: centre.x, y: centre.y + offset)
        }
        let points = ends.compactMap { TrackPoint(at: $0, size: size, in: image) }

        return points.count == ends.count ? points : nil
    }

    private func distance(
        _ point: CGPoint,
        _ other: CGPoint
    ) -> Double {
        hypot(other.x - point.x, other.y - point.y)
    }

    private func midpoint(
        _ point: CGPoint,
        _ other: CGPoint
    ) -> CGPoint {
        CGPoint(x: (point.x + other.x) / 2, y: (point.y + other.y) / 2)
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
        _ target: Rectangle,
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

        return backward.reversed() + [TrackedFrame(time: times[start], rectangle: target)] + forward
    }
}

//
//  TrackPoint.swift
//  FramesTracker
//
//  Created by JSilver on 11/16/26.
//

import Foundation

// A point of the target on its own frame and its feature, the region around it there read in the target's own axes.
// On another frame the point is where the feature best matches the window around where it is expected, read at the
// scale and angle expected, so each frame is matched to the target's own frame and errors do not build up from frame
// to frame.
struct TrackPoint {
    // MARK: - Property
    private static let matcher = TemplateMatcher(reach: 48, levels: 2)
    private static let reach = 48.0

    let point: CGPoint

    private let feature: GreyImage
    private let sampler = RegionSampler()

    // MARK: - Initializer
    // A feature whose pixels are all one grey has nothing to match, and is not a track point. `angle` is the target's
    // on its own frame, in radians clockwise.
    init?(
        at point: CGPoint,
        size: CGSize,
        angle: Double,
        in image: GreyImage
    ) {
        let feature = RegionSampler().sample(image, centre: point, size: size, scale: 1, angle: angle)
        let values = feature.values.filter { !$0.isNaN }
        guard let first = values.first, values.contains(where: { $0 != first }) else { return nil }

        self.point = point
        self.feature = feature
    }

    // MARK: - Public
    // The point on `image`, from the window around `expected` with the feature read at `scale` times its size on the
    // target's frame and turned to `angle`, in radians clockwise. An offset in the window's pixels is that turn and
    // scale of an offset in the image's.
    func find(
        in image: GreyImage,
        near expected: CGPoint,
        scale: Double,
        angle: Double
    ) -> TrackPointMatch? {
        let size = CGSize(
            width: Double(feature.width) + 2 * Self.reach,
            height: Double(feature.height) + 2 * Self.reach
        )
        let window = sampler.sample(image, centre: expected, size: size, scale: scale, angle: angle)
        guard let match = Self.matcher.match(feature, in: window) else { return nil }

        let cosine = cos(angle) * scale
        let sine = sin(angle) * scale
        return TrackPointMatch(
            point: CGPoint(
                x: expected.x + match.offset.x * cosine - match.offset.y * sine,
                y: expected.y + match.offset.x * sine + match.offset.y * cosine
            ),
            correlation: match.correlation
        )
    }

    // MARK: - Private
}

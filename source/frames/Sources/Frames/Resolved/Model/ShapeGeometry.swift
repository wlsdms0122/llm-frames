//
//  ShapeGeometry.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a shape entry is placed, its keyframes in sequence time: a rect or an ellipse by its box, `width` by `height` in
// output pixels, or by its `area` in its coordinate space, or a path by its vertices, each vertex's point and tangents
// timed apart, joined back to the first when `isClosed`. A rect's or an ellipse's `outset`, timed and in output pixels, grows only the outline it draws on every
// side, and its box is as written. A shape placed by its area or its points carries where it goes.
enum ShapeGeometry: Equatable, Sendable {
    case box(width: [Keyframe<Double>], height: [Keyframe<Double>], outset: TimedValue)
    case area(FollowedValue<GeometryArea>, outset: TimedValue, placement: GeometryPlacement)
    case points([PathVertex<FollowedValue<GeometryPoint>, FollowedValue<Point>>], isClosed: Bool, placement: GeometryPlacement)

    // MARK: - Property
    // Where a shape placed by its geometry goes, nil for one placed by its box.
    var placement: GeometryPlacement? {
        switch self {
        case .box:
            nil

        case let .area(_, _, placement), let .points(_, _, placement):
            placement
        }
    }

    // Whether a keyframe of its area, points or position is a clip area, which only evaluation knows the rectangle of.
    var holdsClipArea: Bool {
        let position = placement?.position?.values.contains { $0.clipArea != nil } ?? false
        return position || geometryHoldsClipArea
    }

    // Whether a keyframe of its area or points is a clip area, so its geometry's box is known only at each instant.
    var geometryHoldsClipArea: Bool {
        switch self {
        case .box:
            false

        case let .area(area, _, _):
            area.values.contains { $0.clipArea != nil }

        case let .points(points, _, _):
            points.contains { $0.vertex.values.contains { $0.clipArea != nil } }
        }
    }

    // MARK: - Public
    // MARK: - Private
}

//
//  ResolvedMaskGeometry.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A mask's geometry with each of its numbers timed: a rect with its corner radius, an ellipse, or a closed polyline
// with a keyframe list per point, a point of which may be a clip area's.
enum ResolvedMaskGeometry: Equatable, Sendable {
    case rect(ResolvedMaskRectangle, radius: [Keyframe<Double>])
    case ellipse(ResolvedMaskRectangle)
    case polyline([[Keyframe<GeometryPoint>]])

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func sampled(at time: SampleTime) -> PathGeometry {
        switch self {
        case let .rect(rectangle, radius):
            .rect(rectangle.sampled(at: time), radius: max(radius.value(at: time), 0))

        case let .ellipse(rectangle):
            .ellipse(rectangle.sampled(at: time))

        case let .polyline(points):
            .polyline(points.map { $0.map { $0.map(\.fixed) }.value(at: time) }, isClosed: true)
        }
    }

    // MARK: - Private
}

//
//  ResolvedMaskGeometry.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// A mask's geometry with each of its numbers timed: a rect with its corner radius, an ellipse, or a closed path with a
// keyframe list for each vertex's point, which may be a clip area's, and for each of its tangents.
enum ResolvedMaskGeometry: Equatable, Sendable {
    case rect(ResolvedMaskRectangle, radius: FollowedValue<Double>)
    case ellipse(ResolvedMaskRectangle)
    case path([PathVertex<FollowedValue<GeometryPoint>, FollowedValue<Point>>])

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func sampled(at time: SampleTime) -> PathGeometry {
        switch self {
        case let .rect(rectangle, radius):
            .rect(rectangle.sampled(at: time), radius: max(radius.value(at: time), 0))

        case let .ellipse(rectangle):
            .ellipse(rectangle.sampled(at: time))

        case let .path(vertices):
            .polyline(vertices.map { $0.vertex.mapValues(\.fixed).value(at: time) }, isClosed: true)
        }
    }

    // MARK: - Private
}

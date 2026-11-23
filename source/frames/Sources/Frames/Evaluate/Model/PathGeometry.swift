//
//  PathGeometry.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The outline of a `path` item or a mask: a rectangle with circular corners of `radius`, the ellipse inscribed in a
// rectangle, or a path of cubic Bézier segments through its vertices in order, back to the first when closed, each
// segment's control points its first vertex plus its out tangent and the next vertex plus its in tangent (FRAMES-20).
// A keyframed mask's geometry interpolates per component: a rectangle and its radius, and a path vertex by vertex.
package enum PathGeometry: Interpolable {
    case rect(Rectangle, radius: Double)
    case ellipse(Rectangle)
    case path([PathVertex<Point, Point>], isClosed: Bool)

    // MARK: - Property
    // MARK: - Initializer
    // A path of straight segments through `points`, every tangent 0.
    package static func polyline(
        _ points: [Point],
        isClosed: Bool
    ) -> PathGeometry {
        let zero = Point(x: 0, y: 0)
        return .path(points.map { PathVertex(vertex: $0, inTangent: zero, outTangent: zero) }, isClosed: isClosed)
    }

    // MARK: - Public
    static func interpolate(
        from start: PathGeometry,
        to end: PathGeometry,
        progress: Double
    ) -> PathGeometry {
        switch (start, end) {
        case let (.rect(from, fromRadius), .rect(to, toRadius)):
            .rect(
                .interpolate(from: from, to: to, progress: progress),
                radius: .interpolate(from: fromRadius, to: toRadius, progress: progress)
            )

        case let (.ellipse(from), .ellipse(to)):
            .ellipse(.interpolate(from: from, to: to, progress: progress))

        case let (.path(from, isClosed), .path(to, _)):
            .path(.interpolate(from: from, to: to, progress: progress), isClosed: isClosed)

        // Resolve stops on keyframes whose geometry differs in form, so this pair is never interpolated.
        default:
            start
        }
    }

    // The box of the outline carried by `transform`: a rectangle's or an ellipse's carried corners, which hold it, and a
    // path's curve, its tight box (FRAMES-11 Shapes).
    func bounds(carriedBy transform: AffineTransform = .identity) -> Rectangle {
        switch self {
        case let .rect(rectangle, _), let .ellipse(rectangle):
            Rectangle(bounding: transform.apply(toCornersOf: rectangle))

        case let .path(vertices, isClosed):
            vertices.map { $0.carried(by: transform) }.bounds(isClosed: isClosed)
        }
    }

    // MARK: - Private
}

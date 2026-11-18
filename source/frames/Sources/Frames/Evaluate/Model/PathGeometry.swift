//
//  PathGeometry.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The outline of a `path` item or a mask: a rectangle with circular corners of `radius`, the ellipse inscribed in a
// rectangle, or straight segments through points in order, back to the first when closed. A keyframed mask's
// geometry interpolates per component: a rectangle and its radius, and a polyline point by point.
package enum PathGeometry: Interpolable {
    case rect(Rectangle, radius: Double)
    case ellipse(Rectangle)
    case polyline([Point], isClosed: Bool)

    // MARK: - Property
    // MARK: - Initializer
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

        case let (.polyline(from, isClosed), .polyline(to, _)):
            .polyline(.interpolate(from: from, to: to, progress: progress), isClosed: isClosed)

        // Resolve stops on keyframes whose geometry differs in form, so this pair is never interpolated.
        default:
            start
        }
    }

    // MARK: - Private
}

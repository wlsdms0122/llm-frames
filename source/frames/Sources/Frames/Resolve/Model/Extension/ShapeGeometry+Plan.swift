//
//  ShapeGeometry+Plan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape's geometry plan made its geometry and where it goes, every static property one keyframe at the clip's
// instant. This is the one place a plan becomes geometry: it holds the keyframes its caller gives, and names its
// anchor once, as a point of its geometry's box at the instant where that box lies for its evaluation, which brings a
// tracked shape's keyframes back through its track to the instant. So the entry, the transform resolve plans for a
// shape parent and the bounds evaluation lays out take the anchor in one space. A shape placed by its area or its
// points was checked to write them, so they were found.
extension ShapeGeometry {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: ShapeGeometryPlan,
        area: [Keyframe<Rectangle>]?,
        points: [Keyframe<[Point]>]?,
        position: [Keyframe<Point>]?,
        instant: Double,
        track: TrackedMedia?
    ) {
        switch plan {
        case let .box(width, height, outset):
            self = .box(
                width: width.keyframes(at: instant) { $0 },
                height: height.keyframes(at: instant) { $0 },
                outset: outset
            )

        case let .area(outset, anchor):
            let area = area ?? []
            let box = (track?.area(area) ?? area).value(at: instant)
            self = .area(
                area,
                outset: outset,
                placement: GeometryPlacement(position: position, anchor: anchor.map { box.point(named: $0) })
            )

        case let .points(isClosed, anchor):
            let points = points ?? []
            let box = Rectangle(bounding: (track?.points(points) ?? points).value(at: instant))
            self = .points(
                points,
                isClosed: isClosed,
                placement: GeometryPlacement(position: position, anchor: anchor.map { box.point(named: $0) })
            )
        }
    }

    // MARK: - Public
    // MARK: - Private
}

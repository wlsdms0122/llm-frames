//
//  ShapeGeometry+Plan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// A shape's geometry plan made its geometry and where it goes, every static property one keyframe at the clip's
// instant. The anchor is named once, as a point of the geometry's box at the instant where evaluation lays that box
// out, a tracked shape's keyframes brought back through its track to the track's frame, and a path's box is the box of
// its curve (FRAMES-11 Shapes). A geometry that holds a clip
// area has a box only evaluation knows, so its anchor keeps its name and is placed on that box at each instant. The
// shape's entry and the transform resolve plans for a shape parent are both made here, so they and evaluation take the
// anchor in one space. A shape placed by its area or its points was checked to write them, so they were found.
extension ShapeGeometry {
    // MARK: - Property
    // MARK: - Initializer
    init(
        plan: ShapeGeometryPlan,
        area: FollowedValue<GeometryArea>?,
        points: [PathVertex<FollowedValue<GeometryPoint>, FollowedValue<Point>>]?,
        position: FollowedValue<GeometryPoint>?,
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
            let area = area ?? .keyframes([])
            let box = { (track?.area(area) ?? area).mapValues(\.fixed).value(at: instant) }
            let holdsClipArea = area.values.contains { $0.clipArea != nil }
            self = .area(
                area,
                outset: outset,
                placement: GeometryPlacement(
                    position: position,
                    anchor: anchor.map { Self.anchor(named: $0, holdsClipArea: holdsClipArea, in: box) }
                )
            )

        case let .points(isClosed, anchor):
            let points = points ?? []
            let box = { Self.bounds(of: track?.vertices(points) ?? points, isClosed: isClosed, at: instant) }
            let holdsClipArea = points.contains { $0.vertex.values.contains { $0.clipArea != nil } }
            self = .points(
                points,
                isClosed: isClosed,
                placement: GeometryPlacement(
                    position: position,
                    anchor: anchor.map { Self.anchor(named: $0, holdsClipArea: holdsClipArea, in: box) }
                )
            )
        }
    }

    // MARK: - Public
    // The box of a path's curve at a time, its points and tangents at that time. A clip area's point takes no part.
    static func bounds(
        of vertices: [PathVertex<FollowedValue<GeometryPoint>, FollowedValue<Point>>],
        isClosed: Bool,
        at time: Double
    ) -> Rectangle {
        vertices
            .map { vertex in
                vertex.map(vertex: { $0.mapValues(\.fixed).value(at: time) }, tangent: { $0.value(at: time) })
            }
            .bounds(isClosed: isClosed)
    }

    // MARK: - Private
    private static func anchor(
        named name: String,
        holdsClipArea: Bool,
        in box: () -> Rectangle
    ) -> GeometryAnchor {
        holdsClipArea ? .named(name) : .point(box().point(named: name))
    }
}

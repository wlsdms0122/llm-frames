//
//  ShapeGeometry.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a shape entry is placed (FRAMES-11), its keyframes in sequence time: a rect or an ellipse by its box, `width` by
// `height` in output pixels grown on every side by `outset` in output pixels, or by its `area` in its coordinate
// space, grown by `outset` when it is drawn, or a path by its `points`, joined back to the first when `isClosed`. A
// shape placed by its area or its points carries where it goes.
enum ShapeGeometry: Equatable, Sendable {
    case box(width: [Keyframe<Double>], height: [Keyframe<Double>], outset: Double)
    case area([Keyframe<Rectangle>], outset: Double, placement: GeometryPlacement)
    case points([Keyframe<[Point]>], isClosed: Bool, placement: GeometryPlacement)

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

    // MARK: - Initializer
    // MARK: - Public
    // The box of the geometry as written at a time, before its outset: a box shape's in its own pixels, an area, or the
    // box bounding the points.
    func bounds(at time: Double) -> Rectangle {
        switch self {
        case let .box(width, height, _):
            Rectangle(x: 0, y: 0, width: width.value(at: time), height: height.value(at: time))

        case let .area(area, _, _):
            area.value(at: time)

        case let .points(points, _, _):
            Rectangle(bounding: points.value(at: time))
        }
    }

    // MARK: - Private
}

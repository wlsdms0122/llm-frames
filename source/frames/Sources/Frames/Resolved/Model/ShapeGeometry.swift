//
//  ShapeGeometry.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a shape entry is placed (FRAMES-11), its keyframes in sequence time: a rect or an ellipse by its box, `width` by
// `height` in output pixels, or by its `area` in its coordinate space, either grown on every side by `outset` in
// output pixels when it is drawn, or a path by its `points`, joined back to the first when `isClosed`.
enum ShapeGeometry: Equatable, Sendable {
    case box(width: [Keyframe<Double>], height: [Keyframe<Double>], outset: Double)
    case area([Keyframe<Rectangle>], outset: Double)
    case points([Keyframe<[Point]>], isClosed: Bool)

    // MARK: - Property
    // How far the box is grown on every side, in output pixels. A path has no outset.
    var outset: Double {
        switch self {
        case let .box(_, _, outset), let .area(_, outset):
            outset

        case .points:
            0
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

        case let .area(area, _):
            area.value(at: time)

        case let .points(points, _):
            Rectangle(bounding: points.value(at: time))
        }
    }

    // MARK: - Private
}

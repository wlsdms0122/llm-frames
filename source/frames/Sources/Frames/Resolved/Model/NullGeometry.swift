//
//  NullGeometry.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// How a null entry's box is given, its keyframes in sequence time: by `width` and `height` in output pixels, placed as
// the entry's box, or by its `area` in its coordinate space, which carries where it goes, as a rect's are.
enum NullGeometry: Equatable, Sendable {
    case box(width: [Keyframe<Double>], height: [Keyframe<Double>])
    case area(FollowedValue<GeometryArea>, placement: GeometryPlacement)

    // MARK: - Property
    // The geometry of a rect given the same way, which places and moves a box as a null's is placed and moved.
    var shape: ShapeGeometry {
        switch self {
        case let .box(width, height):
            .box(width: width, height: height, outset: .off)

        case let .area(area, placement):
            .area(area, outset: .off, placement: placement)
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

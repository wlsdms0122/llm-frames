//
//  ResolvedMaskRectangle.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// The rectangle of a rect or an ellipse mask, as the clip gives it: an area, or a box of `width` by `height` centred on
// `position`, each a keyframe list of its own. An area or a position may be a clip area, which evaluation takes at
// each instant before it samples the mask.
enum ResolvedMaskRectangle: Equatable, Sendable {
    case area(FollowedValue<GeometryArea>)
    case box(width: FollowedValue<Double>, height: FollowedValue<Double>, position: FollowedValue<GeometryPoint>)

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // A size sampled below 0 by an ease that overshoots is 0.
    func sampled(at time: Double) -> Rectangle {
        switch self {
        case let .area(area):
            let rectangle = area.mapValues(\.fixed).value(at: time)
            return Rectangle(
                x: rectangle.x,
                y: rectangle.y,
                width: max(rectangle.width, 0),
                height: max(rectangle.height, 0)
            )

        case let .box(width, height, position):
            return Rectangle(
                center: position.mapValues(\.fixed).value(at: time),
                width: max(width.value(at: time), 0),
                height: max(height.value(at: time), 0)
            )
        }
    }

    // MARK: - Private
}

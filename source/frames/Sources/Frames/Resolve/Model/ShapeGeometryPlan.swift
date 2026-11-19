//
//  ShapeGeometryPlan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a shape clip is placed, as planned with its style: a rect or an ellipse by its box, `width` by `height` in output
// pixels with keyframes in sequence time, or by its area, or a path by its points. Resolve finds the area and the
// points apart. `outset`, timed, is in output pixels and grows the outline the shape draws. `anchor` is the anchor
// point named on the geometry's box, nil for the centre of that box.
enum ShapeGeometryPlan: Equatable, Sendable {
    case box(width: PropertyValue<Double>, height: PropertyValue<Double>, outset: TimedValue)
    case area(outset: TimedValue, anchor: String?)
    case points(isClosed: Bool, anchor: String?)
}

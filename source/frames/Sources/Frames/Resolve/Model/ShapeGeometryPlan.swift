//
//  ShapeGeometryPlan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a shape clip is placed, as planned with its style (FRAMES-11): a rect or an ellipse by its box, `width` by
// `height` in output pixels with keyframes in sequence time, or by its area, which resolve finds apart, either with the
// `outset` in output pixels that grows the outline it draws, or a path by its points, which resolve finds apart, closed
// or not. A shape placed by its area or its points takes `anchor`, the anchor point it names on its geometry's box, nil
// for the centre of that box.
enum ShapeGeometryPlan: Equatable, Sendable {
    case box(width: PropertyValue<Double>, height: PropertyValue<Double>, outset: Double)
    case area(outset: Double, anchor: String?)
    case points(isClosed: Bool, anchor: String?)
}

//
//  ShapeGeometryPlan.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// How a shape clip is placed, as planned with its style (FRAMES-11): a rect or an ellipse by its box, `width` by
// `height` in output pixels with keyframes in sequence time, or by its area, which resolve finds apart, either grown on
// every side by `outset` in output pixels, or a path by its points, which resolve finds apart, closed or not.
enum ShapeGeometryPlan: Equatable, Sendable {
    case box(width: PropertyValue<Double>, height: PropertyValue<Double>, outset: Double)
    case area(outset: Double)
    case points(isClosed: Bool)
}

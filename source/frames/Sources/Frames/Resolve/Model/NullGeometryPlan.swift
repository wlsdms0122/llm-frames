//
//  NullGeometryPlan.swift
//  Frames
//
//  Created by JSilver on 11/25/26.
//

// How a null clip is placed, as planned: by its box, `width` by `height` in output pixels with keyframes in sequence
// time, or by its area, which resolve finds apart. `anchor` is the anchor point named on the area, nil for its centre.
enum NullGeometryPlan: Equatable, Sendable {
    case box(width: PropertyValue<Double>, height: PropertyValue<Double>)
    case area(anchor: String?)
}

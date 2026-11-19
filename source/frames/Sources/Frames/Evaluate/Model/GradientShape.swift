//
//  GradientShape.swift
//  Frames
//
//  Created by JSilver on 11/19/26.
//

// Where a gradient lays its positions, in an item's own coordinates: along the line from `from` to `to`, or out from
// `center` to `radius`.
package enum GradientShape: Equatable, Sendable {
    case linear(from: Point, to: Point)
    case radial(center: Point, radius: Double)
}

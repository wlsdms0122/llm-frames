//
//  PathGeometry.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// The outline of a `path` item: a rectangle with circular corners of `radius`, the ellipse inscribed in a rectangle,
// or straight segments through points in order, back to the first when closed.
package enum PathGeometry: Equatable, Sendable {
    case rect(Rectangle, radius: Double)
    case ellipse(Rectangle)
    case polyline([Point], isClosed: Bool)
}

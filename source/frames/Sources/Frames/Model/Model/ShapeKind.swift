//
//  ShapeKind.swift
//  Frames
//
//  Created by JSilver on 11/18/26.
//

// What a shape clip draws: a rectangle or an ellipse in a box, or a path through its points.
enum ShapeKind: String, CaseIterable, Equatable, Sendable {
    case rect
    case ellipse
    case path
}

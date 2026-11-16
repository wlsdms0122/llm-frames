//
//  ShapeKind.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a shape draws on its area: a box around it, a fill over it, a dim over it, or an arrow pointing at it.
enum ShapeKind: String, CaseIterable, Equatable, Sendable {
    case box
    case fill
    case dim
    case arrow
}

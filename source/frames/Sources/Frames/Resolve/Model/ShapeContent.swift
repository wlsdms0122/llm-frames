//
//  ShapeContent.swift
//  Frames
//
//  Created by JSilver on 11/17/26.
//

// What a shape draws once its drawing is laid on an area, in the coordinates of that area. A box strokes the
// rectangle's edge, a fill covers it, a dim darkens its room except the rectangle, and an arrow runs from its tail to
// its tip.
enum ShapeContent: Equatable, Sendable {
    case box(Rectangle, width: Double, radius: Double, color: Color)
    case fill(Rectangle, color: Color)
    case dim(Rectangle, color: Color)
    case arrow(tail: Point, tip: Point, width: Double, head: Double, color: Color)
}

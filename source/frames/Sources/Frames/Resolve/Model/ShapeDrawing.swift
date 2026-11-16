//
//  ShapeDrawing.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// How a shape is drawn on its area, its theme lengths scaled: a box strokes the area's edge `width` wide with corners
// of `radius`, a fill covers the area and a dim darkens around it, and an arrow points at the middle of its `side` of
// the area from a tail `length` beyond it, its line `width` wide and its head `head` long.
enum ShapeDrawing: Equatable, Sendable {
    case box(width: Double, radius: Double, color: Color)
    case fill(color: Color)
    case dim(color: Color)
    case arrow(side: Side, length: Double, width: Double, head: Double, color: Color)
}

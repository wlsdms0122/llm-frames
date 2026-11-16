//
//  ResolvedDrawingContent.swift
//  Frames
//
//  Created by JSilver on 11/16/26.
//

// What a drawing step draws, in output pixels. A picture shows `crop`, in its own pixels, scaled into `frame`. A box
// strokes its rectangle's edge and a border strokes inside it. Dim darkens the step's clip except the rectangle. An
// adjustment applies its filter to what the steps before it drew, inside its area. Text is set in its own box and
// scaled into `frame`.
enum ResolvedDrawingContent: Equatable, Sendable {
    case picture(ResolvedDrawnPicture, crop: Rectangle, frame: Rectangle)
    case fill(Rectangle, color: Color)
    case box(Rectangle, width: Double, radius: Double, color: Color)
    case dim(Rectangle, color: Color)
    case arrow(tail: Point, tip: Point, width: Double, head: Double, color: Color)
    case adjustment([ResolvedFilterOperation], area: Rectangle)
    case text(ResolvedText, frame: Rectangle)
    case border(Rectangle, width: Double, color: Color)
}
